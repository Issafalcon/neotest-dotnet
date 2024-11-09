#r "nuget: Microsoft.TestPlatform.TranslationLayer, 17.11.0"
#r "nuget: Microsoft.TestPlatform.ObjectModel, 17.11.0"
#r "nuget: Microsoft.VisualStudio.TestPlatform, 14.0.0"
#r "nuget: MSTest.TestAdapter, 3.3.1"
#r "nuget: MSTest.TestFramework, 3.3.1"
#r "nuget: Newtonsoft.Json, 13.0.0"

open System
open System.IO
open Newtonsoft.Json
open System.Collections.Generic
open Microsoft.TestPlatform.VsTestConsole.TranslationLayer
open Microsoft.VisualStudio.TestPlatform.ObjectModel
open Microsoft.VisualStudio.TestPlatform.ObjectModel.Client

module TestDiscovery =
    [<return: Struct>]
    let (|DiscoveryRequest|_|) (str: string) =
        if str.StartsWith("discover") then
            let args =
                str.Split(" ", StringSplitOptions.TrimEntries &&& StringSplitOptions.RemoveEmptyEntries)
                |> Array.tail

            {| OutputPath = Array.head args
               Sources = args |> Array.tail |}
            |> ValueOption.Some
        else
            ValueOption.None

    [<return: Struct>]
    let (|RunTests|_|) (str: string) =
        if str.StartsWith("run-tests") then
            let args =
                str.Split(" ", StringSplitOptions.TrimEntries &&& StringSplitOptions.RemoveEmptyEntries)
                |> Array.tail

            {| StreamPath = args[0]
               OutputPath = args[1]
               Ids = args[2..] |> Array.map Guid.Parse |}
            |> ValueOption.Some
        else
            ValueOption.None

    let discoveredTests = Dictionary<string, TestCase seq>()

    type PlaygroundTestDiscoveryHandler() =
        interface ITestDiscoveryEventsHandler2 with
            member _.HandleDiscoveredTests(discoveredTestCases: IEnumerable<TestCase>) =
                discoveredTestCases
                |> Seq.groupBy _.CodeFilePath
                |> Seq.iter (fun (file, testCase) -> 
                  if discoveredTests.ContainsKey file then
                    discoveredTests.Remove(file) |> ignore
                  discoveredTests.Add(file, testCase))

            member _.HandleDiscoveryComplete(_, _) = ()

            member _.HandleLogMessage(_, _) = ()
            member _.HandleRawMessage(_) = ()

    type PlaygroundTestRunHandler(streamOutputPath, outputFilePath) =
        interface ITestRunEventsHandler with
            member _.HandleTestRunComplete
                (_testRunCompleteArgs, _lastChunkArgs, _runContextAttachments, _executorUris)
                =
                ()

            member __.HandleLogMessage(_level, _message) = ()

            member __.HandleRawMessage(_rawMessage) = ()

            member __.HandleTestRunStatsChange(testRunChangedArgs: TestRunChangedEventArgs) : unit =
                let toNeoTestStatus (outcome: TestOutcome) =
                    match outcome with
                    | TestOutcome.Passed -> "passed"
                    | TestOutcome.Failed -> "failed"
                    | TestOutcome.Skipped -> "skipped"
                    | TestOutcome.None -> "skipped"
                    | TestOutcome.NotFound -> "skipped"
                    | _ -> "skipped"

                let results =
                    testRunChangedArgs.NewTestResults
                    |> Seq.map (fun result ->
                        let outcome = toNeoTestStatus result.Outcome

                        let errorMessage =
                            let message = result.ErrorMessage |> Option.ofObj
                            let stackTrace = result.ErrorStackTrace |> Option.ofObj

                            match message, stackTrace with
                            | Some message, Some stackTrace -> Some $"{message}{Environment.NewLine}{stackTrace}"
                            | Some message, None -> Some message
                            | None, Some stackTrace -> Some stackTrace
                            | None, None -> None

                        let errors =
                            match errorMessage with
                            | Some error -> [| {| message = error |} |]
                            | None -> [||]

                        result.TestCase.Id,
                        {| status = outcome
                           short = $"{result.TestCase.DisplayName}:{outcome}"
                           errors = errors |})

                use streamWriter = new StreamWriter(streamOutputPath, append = true)

                for (id, result) in results do
                    {| id = id; result = result |}
                    |> JsonConvert.SerializeObject
                    |> streamWriter.WriteLine

                use outputWriter = new StreamWriter(outputFilePath, append = false)
                outputWriter.WriteLine(JsonConvert.SerializeObject(Map.ofSeq results))

            member __.LaunchProcessWithDebuggerAttached(_testProcessStartInfo) = 1

    let main (argv: string[]) =
        if argv.Length <> 1 then
            invalidArg "CommandLineArgs" "Usage: fsi script.fsx <vstest-console-path>"

        let console = argv[0]

        let sourceSettings =
            """
        <RunSettings>
        </RunSettings>
        """

        let environmentVariables =
            Map.empty
            |> Map.add "VSTEST_CONNECTION_TIMEOUT" "999"
            |> Map.add "VSTEST_DEBUG_NOBP" "1"
            |> Map.add "VSTEST_RUNNER_DEBUG_ATTACHVS" "0"
            |> Map.add "VSTEST_HOST_DEBUG_ATTACHVS" "0"
            |> Map.add "VSTEST_DATACOLLECTOR_DEBUG_ATTACHVS" "0"
            |> Dictionary

        let options = TestPlatformOptions(CollectMetrics = false)

        let r =
            VsTestConsoleWrapper(console, ConsoleParameters(EnvironmentVariables = environmentVariables))

        let testSession = TestSessionInfo()
        let discoveryHandler = PlaygroundTestDiscoveryHandler()

        r.StartSession()

        let mutable loop = true

        while loop do
            match Console.ReadLine() with
            | DiscoveryRequest args ->
                r.DiscoverTests(args.Sources, sourceSettings, options, testSession, discoveryHandler)

                use streamWriter = new StreamWriter(args.OutputPath, append = false)
                discoveredTests
                |> _.Values
                |> Seq.collect (Seq.map (fun testCase -> testCase.Id, testCase))
                |> Map
                |> JsonConvert.SerializeObject 
                |> streamWriter.WriteLine

                Console.WriteLine($"Wrote test results to {args.OutputPath}")
            | RunTests args ->
                let idMap =
                  discoveredTests
                  |> _.Values
                  |> Seq.collect (Seq.map (fun testCase -> testCase.Id, testCase))
                  |> Map

                let testCases =
                  args.Ids
                  |> Array.choose (fun id -> Map.tryFind id idMap)

                let testHandler = PlaygroundTestRunHandler(args.StreamPath, args.OutputPath)
                r.RunTests(testCases, sourceSettings, testHandler)
            | _ -> loop <- false

        r.EndSession()

        0

    let args = fsi.CommandLineArgs |> Array.tail

    main args

#r "nuget: Microsoft.TestPlatform.TranslationLayer, 17.11.0"
#r "nuget: Microsoft.TestPlatform.ObjectModel, 17.11.0"
#r "nuget: Microsoft.VisualStudio.TestPlatform, 14.0.0"
#r "nuget: MSTest.TestAdapter, 3.3.1"
#r "nuget: MSTest.TestFramework, 3.3.1"
#r "nuget: Newtonsoft.Json, 13.0.0"

open System
open System.IO
open System.Threading
open System.Threading.Tasks
open Newtonsoft.Json
open System.Collections.Generic
open System.Collections.Concurrent
open Microsoft.TestPlatform.VsTestConsole.TranslationLayer
open Microsoft.VisualStudio.TestPlatform.ObjectModel
open Microsoft.VisualStudio.TestPlatform.ObjectModel.Client
open Microsoft.VisualStudio.TestPlatform.ObjectModel.Client.Interfaces
open Microsoft.VisualStudio.TestPlatform.ObjectModel.Logging

type NeoTestResultError = { message: string }

type NeotestResult =
    { status: string
      short: string
      output: string
      errors: NeoTestResultError array }

module TestDiscovery =
    let parseArgs (args: string) =
        args.Split(" ", StringSplitOptions.TrimEntries &&& StringSplitOptions.RemoveEmptyEntries)
        |> Array.tail

    [<return: Struct>]
    let (|DiscoveryRequest|_|) (str: string) =
        if str.StartsWith("discover") then
            let args = parseArgs str

            {| OutputPath = args[0]
               WaitFile = args[1]
               Sources = args[2..] |}
            |> ValueOption.Some
        else
            ValueOption.None

    [<return: Struct>]
    let (|RunTests|_|) (str: string) =
        if str.StartsWith("run-tests") then
            let args = parseArgs str

            {| StreamPath = args[0]
               OutputPath = args[1]
               ProcessOutput = args[2]
               Ids = args[3..] |> Array.map Guid.Parse |}
            |> ValueOption.Some
        else
            ValueOption.None

    [<return: Struct>]
    let (|DebugTests|_|) (str: string) =
        if str.StartsWith("debug-tests") then
            let args = parseArgs str

            {| PidPath = args[0]
               AttachedPath = args[1]
               StreamPath = args[2]
               OutputPath = args[3]
               ProcessOutput = args[4]
               Ids = args[5..] |> Array.map Guid.Parse |}
            |> ValueOption.Some
        else
            ValueOption.None

    let logHandler (level: TestMessageLevel) (message: string) =
        if not <| String.IsNullOrWhiteSpace message then
            if level = TestMessageLevel.Error then
                Console.Error.WriteLine(message)
            else
                Console.WriteLine(message)

    type TestCaseDto =
        { CodeFilePath: string
          DisplayName: string
          LineNumber: int
          FullyQualifiedName: string }

    let discoveredTests = ConcurrentDictionary<string, TestCase seq>()

    let getTestCases ids =
        let idMap =
            discoveredTests
            |> _.Values
            |> Seq.collect (Seq.map (fun testCase -> testCase.Id, testCase))
            |> Map

        ids |> Array.choose (fun id -> Map.tryFind id idMap)

    type PlaygroundTestDiscoveryHandler() =
        interface ITestDiscoveryEventsHandler2 with
            member _.HandleDiscoveredTests(discoveredTestCases: IEnumerable<TestCase>) =
                discoveredTestCases
                |> Seq.groupBy _.CodeFilePath
                |> Seq.iter (fun (file, testCases) ->
                    discoveredTests.AddOrUpdate(file, testCases, (fun _ _ -> testCases)) |> ignore)

            member _.HandleDiscoveryComplete(_, _) = ()

            member __.HandleLogMessage(level, message) = logHandler level message

            member __.HandleRawMessage(_) = ()

    type PlaygroundTestRunHandler(streamOutputPath, outputFilePath, processOutputPath) =
        let resultsDictionary = ConcurrentDictionary()
        let processOutputWriter = new StreamWriter(processOutputPath, append = true)

        interface ITestRunEventsHandler with
            member _.HandleTestRunComplete
                (_testRunCompleteArgs, _lastChunkArgs, _runContextAttachments, _executorUris)
                =
                use outputWriter = new StreamWriter(outputFilePath, append = false)
                outputWriter.WriteLine(JsonConvert.SerializeObject(resultsDictionary))

            member __.HandleLogMessage(_level, message) =
                if not <| String.IsNullOrWhiteSpace message then
                    processOutputWriter.WriteLine(message)

            member __.HandleRawMessage(_rawMessage) = ()

            member __.HandleTestRunStatsChange(testRunChangedArgs: TestRunChangedEventArgs) : unit =
                let toNeoTestStatus (outcome: TestOutcome) =
                    match outcome with
                    | TestOutcome.Passed -> "passed"
                    | TestOutcome.Failed -> "failed"
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
                            | Some error -> [| { message = error } |]
                            | None -> [||]

                        let id = result.TestCase.Id

                        let neoTestResult =
                            { status = outcome
                              short = $"{result.TestCase.DisplayName}:{outcome}"
                              output = Path.GetTempPath() + Guid.NewGuid().ToString()
                              errors = errors }

                        File.WriteAllText(neoTestResult.output, result.ToString())

                        resultsDictionary.AddOrUpdate(id, neoTestResult, (fun _ _ -> neoTestResult))
                        |> ignore

                        (id, neoTestResult))

                use streamWriter = new StreamWriter(streamOutputPath, append = true)

                for (id, result) in results do
                    {| id = id; result = result |}
                    |> JsonConvert.SerializeObject
                    |> streamWriter.WriteLine

            member __.LaunchProcessWithDebuggerAttached(_testProcessStartInfo) = 1

        interface IDisposable with
            member _.Dispose() = processOutputWriter.Dispose()

    type DebugLauncher(pidFile: string, attachedFile: string) =
        interface ITestHostLauncher2 with
            member this.LaunchTestHost(defaultTestHostStartInfo: TestProcessStartInfo) =
                (this :> ITestHostLauncher)
                    .LaunchTestHost(defaultTestHostStartInfo, CancellationToken.None)

            member _.LaunchTestHost(_defaultTestHostStartInfo: TestProcessStartInfo, _ct: CancellationToken) = 1

            member this.AttachDebuggerToProcess(pid: int) =
                (this :> ITestHostLauncher2)
                    .AttachDebuggerToProcess(pid, CancellationToken.None)

            member _.AttachDebuggerToProcess(pid: int, ct: CancellationToken) =
                use cts = CancellationTokenSource.CreateLinkedTokenSource(ct)
                cts.CancelAfter(TimeSpan.FromSeconds(450.))

                do
                    Console.WriteLine($"spawned test process with pid: {pid}")
                    use pidWriter = new StreamWriter(pidFile, append = false)
                    pidWriter.WriteLine(pid)

                while not (cts.Token.IsCancellationRequested || File.Exists(attachedFile)) do
                    ()

                let attached = File.Exists(attachedFile)

                Console.WriteLine($"Debugger attached: {attached}")

                attached

            member __.IsDebug = true


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
            |> Map.add "DOTNET_ROLL_FORWARD" "Major"
            |> Dictionary

        let options = TestPlatformOptions(CollectMetrics = false)

        let r =
            VsTestConsoleWrapper(console, ConsoleParameters(EnvironmentVariables = environmentVariables))

        let testSession = TestSessionInfo()

        r.StartSession()

        let mutable loop = true

        while loop do
            match Console.ReadLine() with
            | DiscoveryRequest args ->
                // spawn as task to allow running discovery concurrently
                task {
                    do! Task.Yield()

                    try
                        let discoveryHandler =
                            PlaygroundTestDiscoveryHandler() :> ITestDiscoveryEventsHandler2

                        for source in args.Sources do
                            Console.WriteLine($"Discovering tests for: {source}")
                            r.DiscoverTests([| source |], sourceSettings, options, testSession, discoveryHandler)

                        use testsWriter = new StreamWriter(args.OutputPath, append = false)

                        discoveredTests
                        |> Seq.map (fun x ->
                            (x.Key,
                             x.Value
                             |> Seq.map (fun testCase ->
                                 testCase.Id,
                                 { CodeFilePath = testCase.CodeFilePath
                                   DisplayName = testCase.DisplayName
                                   LineNumber = testCase.LineNumber
                                   FullyQualifiedName = testCase.FullyQualifiedName })
                             |> Map))
                        |> Map
                        |> JsonConvert.SerializeObject
                        |> testsWriter.WriteLine
                    with e ->
                        Console.WriteLine($"failed to discovery tests for {args.Sources}. Exception: {e}")

                    use waitFileWriter = new StreamWriter(args.WaitFile, append = false)
                    waitFileWriter.WriteLine("1")

                    Console.WriteLine($"Wrote test results to {args.WaitFile}")
                }
                |> ignore
            | RunTests args ->
                task {
                    let testCases = getTestCases args.Ids

                    use testHandler =
                        new PlaygroundTestRunHandler(args.StreamPath, args.OutputPath, args.ProcessOutput)
                    // spawn as task to allow running concurrent tests
                    do! r.RunTestsAsync(testCases, sourceSettings, testHandler)
                    Console.WriteLine($"Done running tests for ids: ")

                    for id in args.Ids do
                        Console.Write($"{id} ")

                    return ()
                }
                |> ignore
            | DebugTests args ->
                task {
                    let testCases = getTestCases args.Ids

                    use testHandler =
                        new PlaygroundTestRunHandler(args.StreamPath, args.OutputPath, args.ProcessOutput)

                    let debugLauncher = DebugLauncher(args.PidPath, args.AttachedPath)
                    Console.WriteLine($"Starting {testCases.Length} tests in debug-mode")

                    do! Task.Yield()
                    r.RunTestsWithCustomTestHost(testCases, sourceSettings, testHandler, debugLauncher)
                }
                |> ignore
            | _ -> loop <- false

        r.EndSession()

        0

    let args = fsi.CommandLineArgs |> Array.tail

    main args

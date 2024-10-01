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

    let mutable discoveredTests = Seq.empty<TestCase>

    type PlaygroundTestDiscoveryHandler() =
        interface ITestDiscoveryEventsHandler2 with
            member _.HandleDiscoveredTests(discoveredTestCases: IEnumerable<TestCase>) =
                discoveredTests <- discoveredTestCases

            member _.HandleDiscoveryComplete(_, _) = ()
            member _.HandleLogMessage(_, _) = ()
            member _.HandleRawMessage(_) = ()

    type PlaygroundTestRunHandler(outputFilePath) =
        interface ITestRunEventsHandler with
            member _.HandleTestRunComplete
                (_testRunCompleteArgs, _lastChunkArgs, _runContextAttachments, _executorUris)
                =
                ()

            member __.HandleLogMessage(_level, _message) = ()

            member __.HandleRawMessage(_rawMessage) = ()

            member __.HandleTestRunStatsChange(testRunChangedArgs: TestRunChangedEventArgs) : unit =
                use writer = new StreamWriter(outputFilePath, append = false)

                let toNeoTestStatus (outcome: TestOutcome) =
                    match outcome with
                    | TestOutcome.Passed -> "passed"
                    | TestOutcome.Failed -> "failed"
                    | TestOutcome.Skipped -> "skipped"
                    | TestOutcome.None -> "skipped"
                    | TestOutcome.NotFound -> "skipped"
                    | _ -> "skipped"

                testRunChangedArgs.NewTestResults
                |> Seq.map (fun result ->
                    let outcome = toNeoTestStatus result.Outcome

                    let errorMessage =
                        let message = result.ErrorMessage |> Option.ofObj |> Option.defaultValue ""
                        let stackTrace = result.ErrorStackTrace |> Option.ofObj |> Option.defaultValue ""

                        [ message; stackTrace ]
                        |> List.filter (not << String.IsNullOrWhiteSpace)
                        |> String.concat Environment.NewLine

                    result.TestCase.Id,
                    {| status = outcome
                       short = $"{result.TestCase.DisplayName}:{outcome}"
                       errors = [| {| message = errorMessage |} |] |})
                |> Map.ofSeq
                |> JsonConvert.SerializeObject
                |> writer.WriteLine

            member __.LaunchProcessWithDebuggerAttached(_testProcessStartInfo) = 1

    let main (argv: string[]) =
        if argv.Length <> 4 then
            invalidArg
                "CommandLineArgs"
                "Usage: fsi script.fsx <vstest-console-path> <output-path> <list-of-test-ids> <test-dll-path>"

        let console = argv[0]

        let outputPath = argv[1]

        let sourceSettings =
            """
        <RunSettings>
        </RunSettings>
        """

        let testIds =
            argv[2]
                .Split(";", StringSplitOptions.TrimEntries &&& StringSplitOptions.RemoveEmptyEntries)
            |> Array.map Guid.Parse
            |> Set

        let sources = argv[3..]

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

        let discoveryHandler = PlaygroundTestDiscoveryHandler()
        let testHandler = PlaygroundTestRunHandler(outputPath)

        let testSession = TestSessionInfo()

        r.DiscoverTests(sources, sourceSettings, options, testSession, discoveryHandler)

        let testsToRun =
            discoveredTests |> Seq.filter (fun testCase -> Set.contains testCase.Id testIds)

        r.RunTests(testsToRun, sourceSettings, options, testHandler)

        0

    main <| Array.tail fsi.CommandLineArgs

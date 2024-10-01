#r "nuget: Microsoft.TestPlatform.TranslationLayer, 17.11.0"
#r "nuget: Microsoft.VisualStudio.TestPlatform, 14.0.0"
#r "nuget: MSTest.TestAdapter, 3.3.1"
#r "nuget: MSTest.TestFramework, 3.3.1"
#r "nuget: Newtonsoft.Json, 13.0.0"

open System
open System.Collections.Generic
open Newtonsoft.Json
open Microsoft.TestPlatform.VsTestConsole.TranslationLayer
open Microsoft.VisualStudio.TestPlatform.ObjectModel
open Microsoft.VisualStudio.TestPlatform.ObjectModel.Client

module TestDiscovery =
    type Test =
        { Id: Guid
          Namespace: string
          Name: string
          FilePath: string
          LineNumber: int }

    type PlaygroundTestDiscoveryHandler() =
        interface ITestDiscoveryEventsHandler2 with
            member _.HandleDiscoveredTests(discoveredTestCases: IEnumerable<TestCase>) =
                discoveredTestCases
                |> Seq.map (fun testCase ->
                    { Id = testCase.Id
                      Namespace = testCase.FullyQualifiedName
                      Name = testCase.DisplayName
                      FilePath = testCase.CodeFilePath
                      LineNumber = testCase.LineNumber })
                |> JsonConvert.SerializeObject
                |> Console.WriteLine

            member _.HandleDiscoveryComplete(_, _) = ()
            member _.HandleLogMessage(_, _) = ()
            member _.HandleRawMessage(_) = ()

    let main (argv: string[]) =
        if argv.Length <> 2 then
            invalidArg "CommandLineArgs" "Usage: fsi script.fsx <vstest-console-path> <test-dll-path>"

        let console = Array.head argv

        let sourceSettings =
            """
        <RunSettings>
        </RunSettings>
        """

        let sources = Array.tail argv

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

        let testSession = TestSessionInfo()

        r.DiscoverTests(sources, sourceSettings, options, testSession, discoveryHandler)
        0

    main <| Array.tail fsi.CommandLineArgs

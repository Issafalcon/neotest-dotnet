namespace X.Tests

open Xunit
open System.Threading.Tasks

module A =

    [<Fact>]
    let ``My test`` () =
        let fx x =
            let x = 1
            Assert.True(false)

        fx ()

    [<Fact>]
    let ``My test 2`` () =
        let x = 1
        Assert.True(false)

    [<Fact>]
    let ``My test 3`` () =
        let x = 1
        Assert.True(false)

    [<Fact>]
    let ``My slow test`` () =
        task {
            do! Task.Delay(10000)
            Assert.True(true)
        }

    [<Theory>]
    [<InlineData(10, 20, 30)>]
    [<InlineData(11, 22, 33)>]
    let ``Pass cool test parametrized function`` x _y _z = Assert.True(x > 0)


    let notATest () = ()


type ``X Should``() =
    [<Fact>]
    member _.``Pass cool test``() =
        do ()
        do ()
        do ()
        do ()
        Assert.True(true)

    [<Theory>]
    [<InlineData(10, 20, 30)>]
    member _.``Pass cool test parametrized``(x, _y, _z) = Assert.True(x > 0)

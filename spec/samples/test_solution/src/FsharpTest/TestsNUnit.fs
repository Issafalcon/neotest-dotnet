namespace N.Tests

open NUnit.Framework

module A =

    [<Test>]
    let ``My test`` () =
        let x = 1
        let y = 2
        Assert.Pass()

    [<TestCase(10, 20, 30)>]
    [<TestCase(11, 22, 33)>]
    let ``Pass cool x parametrized function`` x _y _z = Assert.That(x > 0)

[<TestFixture>]
type ``X Should``() =
    [<Test>]
    member _.``Pass cool x``() = Assert.Pass()

    [<TestCase(11, 22, 33)>]
    member _.``Pass cool x parametrized``(x, _y, _z) = Assert.That(x > 0)

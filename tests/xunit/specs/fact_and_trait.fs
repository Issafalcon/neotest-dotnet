namespace xunit.testproj1

type UnitTest1() =
	[<Fact>]
	[<Trait("Category", "Integration")>]
  member _.Test1() =
    Assert.Equal(1, 1)

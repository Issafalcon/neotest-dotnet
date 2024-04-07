namespace xunit.testproj1;

public class UnitTest1
{
	[Fact]
	[Trait("Category", "Integration")]
	public void Test1()
	{
		Assert.Equal(1, 1);
	}
}

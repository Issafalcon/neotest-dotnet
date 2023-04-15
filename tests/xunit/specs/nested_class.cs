using Xunit;

namespace XUnitSamples;

public class UnitTest1
{
	[Fact]
	public void Test1()
	{
		Assert.Equal(1, 1);
	}

	public class NestedClass
	{
		[Fact]
		public void Test1()
		{
			Assert.Equal(1, 0);
		}

		[Fact]
		public void Test2()
		{
			Assert.Equal(1, 1);
		}
	}
}

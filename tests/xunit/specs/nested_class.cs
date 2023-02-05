namespace xunit.testproj1;

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
            Assert.AreEqual(1,1);
        }
    }
}

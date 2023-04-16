using NUnit.Framework;

namespace NUnitSamples;

public class SingleTests
{
	[SetUp]
	public void Setup()
	{
	}

	[Test]
	public void Test1()
	{
		Assert.Pass();
	}
}

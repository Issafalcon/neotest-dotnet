using NUnit.Framework;

namespace NUnitSamples;

[TestFixture]
public class Tests
{
    [SetUp]
    public void Setup() { }

    [Test]
    [TestCase(12, 3, 4)]
    [TestCase(12, 2, 6)]
    [TestCase(12, 4, 3)]
    public void DivideTest(int n, int d, int q)
    {
        Assert.AreEqual(q, n / d);
    }
}

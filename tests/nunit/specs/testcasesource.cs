using NUnit.Framework;

namespace NUnitSamples;

[TestFixture]
public class Tests
{
    [SetUp]
    public void Setup()
    {
    }

    [TestCaseSource(nameof(DivideCases))]
    public void DivideTest(int n, int d, int q)
    {
        Assert.AreEqual(q, n / d);
    }

    public static object[] DivideCases =
    {
        new object[] { 12, 4, 4 },
        new object[] { 12, 2, 6 },
        new object[] { 12, 4, 3 }
    };
}

namespace CSharpTest;

public class UnitTest1
{
    [Fact]
    public void Test1() { }

    [Fact(DisplayName = "Name of test 2")]
    public void Test2() { }

    public static TheoryData<DateTime, DateTime> Dates()
    {
        var theory = new TheoryData<DateTime, DateTime>
        {
            { new DateTime(2019, 1, 1, 0, 0, 1), new DateTime(2020, 1, 1, 0, 0, 1) },
            { new DateTime(2019, 1, 1, 0, 0, 1), new DateTime(2019, 12, 31, 23, 59, 59) },
        };
        return theory;
    }

    [Theory]
    [MemberData(nameof(Dates))]
    public void TheoryTest(DateTime startDate, DateTime endDate) {
    }
}

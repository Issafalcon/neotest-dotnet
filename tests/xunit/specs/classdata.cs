using System.Collections;
using System.Collections.Generic;
using Xunit;

namespace XUnitSamples;

public class ClassDataTests
{
	[Theory]
	[ClassData(typeof(NumericTestData))]
	public void Theory_With_Class_Data_Test(int v1, int v2)
	{
		var sum = v1 + v2;
		Assert.True(sum == 3);
	}
}

public class NumericTestData : IEnumerable<object[]>
{
	public IEnumerator<object[]> GetEnumerator()
	{
		yield return new object[] { 1, 2 };
		yield return new object[] { -4, 6 };
		yield return new object[] { -2, 2 };
	}

	IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
}

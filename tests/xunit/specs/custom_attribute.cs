using System.Collections;
using System.Collections.Generic;
using Xunit;

namespace XUnitSamples;

[CollectionDefinition(nameof(CosmosContainer), DisableParallelization = true)]
public class CosmosConnectorTest(CosmosContainer CosmosContainer) : IClassFixture<CosmosContainer>
{
    [SkippableEnvironmentFact("TEST", DisplayName = "Custom attribute works ok")]
    public async void Custom_Attribute_Tests()
    {
        ConnectionInfo connectionInfo = await CosmosContainer.StartContainerOrGetConnectionInfo();
        Assert.Equal("127.0.0.1", connectionInfo.Host);
    }
}

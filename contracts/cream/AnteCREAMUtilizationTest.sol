// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.7.0;
import "../AnteTest.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface ICToken {
    function getCash() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
}

/// @title CREAM utilization rate doesn't spike
/// @notice Ante Test to check the utilization rate of the top 5 CREAM markets doesn't
/// exceed a threshold
contract AnteCREAMUtilizationTest is AnteTest("CREAM utilization doesn't spike") {
    using SafeMath for uint256;

    // top 5 markets on CREAM by $ value
    ICToken[5] public cTokens = [
        ICToken(0xD06527D5e56A3495252A528C4987003b712860eE), // crETH
        ICToken(0x797AAB1ce7c01eB727ab980762bA88e7133d2157), // crUSDT
        ICToken(0x44fbeBd2F576670a6C33f6Fc0B00aA8c5753b322), // crUSDC
        ICToken(0x19D1666f543D42ef17F66E376944A22aEa1a8E46), // crCOMP
        ICToken(0xcE4Fe9b4b8Ff61949DCfeB7e03bc9FAca59D2Eb3)  // crBAL
    ];

    /// @notice minimum period after checkpointing before checkTestPasses call
    /// is allowed to fail
    uint32 public constant MIN_PERIOD = 12 hours;

    /// @notice minimum interval between allowing subsequent checkpoints
    /// @dev prevents malicious stakers from preventing a failing test by calling checkpoint() repeatedly
    uint32 public constant MIN_CHECKPOINT_INTERVAL = 48 hours;

    /// @notice threshold for utilization rate change
    uint256 public constant UTILIZATION_CHANGE_THRESHOLD = 12345; // TODO placeholder, need to calculate

    /// @notice last time a checkpoint was taken
    uint256 public lastCheckpointTime;
    /// @notice CREAM utilization at last checkpoint
    uint256 public lastUtilizationRate;

    constructor() {
        protocolName = "CREAM Finance";

        for (uint256 i = 0; i < 5; i++) {
            ICToken cToken = cTokens[i];
            testedContracts.push(address(cToken));
        }
        checkpoint();
    }

    /// @notice take checkpoint of current CREAM utilization
    function checkpoint() public {
        require(
            block.timestamp.sub(lastCheckpointTime) > MIN_CHECKPOINT_INTERVAL,
            "Cannot call checkpoint more than once every 48 hours"
        );

        lastCheckpointTime = block.timestamp;
        lastUtilizationRate = getCurrentUtilization();
    }

    /// @notice checks that 
    /// @dev 
    /// @return 
    function checkTestPasses() public view override returns (bool) {
        uint256 timeSinceLastCheckpoint = block.timestamp.sub(lastCheckpointTime);
        if (timeSinceLastCheckpoint > MIN_PERIOD) {
            uint256 currUtilization = getCurrentUtilization();

            // if utilization rate decreased then return true to avoid reversion due to underflow
            if (lastUtilizationRate >= currUtilization) {
                return true;
            }

            return currUtilization.sub(lastUtilizationRate).div(timeSinceLastCheckpoint) < UTILIZATION_CHANGE_THRESHOLD;

        }

        // if timeSinceLastCheckpoint is less than MIN_PERIOD just return true
        // don't revert test since this will trigger failure on associated AntePool
        return true;
    }

    /// @notice calculate current CREAM utilization
    function getCurrentUtilization() private view returns (uint256) {
        uint256 totalCreamBorrows;
        uint256 totalCreamSupply;

        for (uint256 i = 0; i < 5; i++) {
            ICToken cToken = cTokens[i];
            totalCreamBorrows.add(cToken.totalBorrows());
            totalCreamSupply.add(cToken.getCash());
        }
        return totalCreamBorrows.mul(100).div(totalCreamSupply);
    }
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.7.0;
import "../AnteTest.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface ICToken {
    function getCash() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function totalReserves() external view returns (uint256);
}

/// @title CREAM utilization rate doesn't spike
/// @notice Ante Test to check the utilization rate of the top 5 CREAM markets doesn't
/// exceed a threshold
contract AnteCREAMUtilizationTest is AnteTest("CREAM utilization doesn't spike for majority of top 5 markets") {
    using SafeMath for uint256;

    // top 5 markets on CREAM by $ value
    ICToken[5] public cTokens = [
        ICToken(0xD06527D5e56A3495252A528C4987003b712860eE), // crETH
        ICToken(0x797AAB1ce7c01eB727ab980762bA88e7133d2157), // crUSDT
        ICToken(0x44fbeBd2F576670a6C33f6Fc0B00aA8c5753b322), // crUSDC
        ICToken(0x19D1666f543D42ef17F66E376944A22aEa1a8E46), // crCOMP
        ICToken(0xcE4Fe9b4b8Ff61949DCfeB7e03bc9FAca59D2Eb3)  // crBAL
    ];

    // threshold amounts by market
    // TODO update actual thresholds
    uint256[5] public thresholds = [
        50, // crETH  - based on historical rate of XX% between mm/dd/yyyy – mm/dd/yyyy
        50, // crUSDT - based on historical rate of XX% between mm/dd/yyyy – mm/dd/yyyy
        50, // crUSDC - based on historical rate of XX% between mm/dd/yyyy – mm/dd/yyyy
        50, // crCOMP - based on historical rate of XX% between mm/dd/yyyy – mm/dd/yyyy
        50  // crBAL  - based on historical rate of XX% between mm/dd/yyyy – mm/dd/yyyy
    ];

    // number of tests that can fail before test fails
    uint32 public constant FAIL_THRESHOLD = 3;

    constructor() {
        protocolName = "CREAM Finance";

        for (uint256 i = 0; i < 5; i++) {
            ICToken cToken = cTokens[i];
            testedContracts.push(address(cToken));
        }
    }

    /// @notice checks that 
    /// @dev 
    /// @return 
    function checkTestPasses() public view override returns (bool) {
        uint256 failedMarkets;

        for (uint256 i = 0; i < 5; i++) {
            ICToken cToken = cTokens[i];
            // total supply = total borrows + cash - reserves
            // do we need to pre-check if getCash + totalBorrows - totalReserves is negative and prevent test reversion?
            uint256 totalSupply = cToken.totalBorrows().add(cToken.getCash()).sub(cToken.totalReserves());
            uint256 utilization = cToken.totalBorrows().mul(100).div(totalSupply);
            if (utilization > thresholds[i]) {
                failedMarkets = failedMarkets.add(1);
            }
        }

        // return true if fewer than 3 markets fail
        return failedMarkets < FAIL_THRESHOLD;
        
    }
}

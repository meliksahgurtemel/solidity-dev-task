// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "src/Vault.sol";
import {IxAnchorBridge} from "src/interfaces/IxAnchorBridge.sol";
import {AggregatorV3Interface} from "src/interfaces/AggregatorV3Interface.sol";

contract aUSTVault is Vault {

    IERC20 public aUST;
    IxAnchorBridge public xAnchorBridge;
    AggregatorV3Interface public priceFeed;

    function initialize(
        address _underlying,
        string memory _name,
        string memory _symbol,
        uint256 _adminFee,
        uint256 _callerFee,
        uint256 _maxReinvestStale,
        address _WAVAX,
        address _xAnchorBridge,
        address _aUST,
        address _priceFeed
    ) public {
        initialize(_underlying,
                    _name,
                    _symbol,
                    _adminFee,
                    _callerFee,
                    _maxReinvestStale,
                    _WAVAX
                    );
        aUST = IERC20(_aUST);
        priceFeed = AggregatorV3Interface(_priceFeed);
        xAnchorBridge = IxAnchorBridge(_xAnchorBridge);
        underlying.approve(address(xAnchorBridge), MAX_INT);
    }

    // Returns the latest price of aUST in UST
    function getLatestPrice() public view returns (uint256) {
        (
            /*uint80 roundID*/,
            int256 price,
            /*uint256  startedAt*/,
            /*uint256  timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function receiptPerUnderlying() public override view returns (uint256) {
        if (totalSupply == 0) {
            return 10 ** (18 + 18 - underlyingDecimal);
        }
        uint256 _USTAmt = (aUST.balanceOf(address(this)) * getLatestPrice()) / 1e18;
        return (1e18 * totalSupply) / _USTAmt;
    }

    function underlyingPerReceipt() public override view returns (uint256) {
        if (totalSupply == 0) {
            return 10 ** underlyingDecimal;
        }
        uint256 _USTAmt = (aUST.balanceOf(address(this)) * getLatestPrice()) / 1e18;
        return (1e18 * _USTAmt) / totalSupply;
    }

    function totalHoldings() public view override returns (uint256) {
        uint256 _USTAmt = (aUST.balanceOf(address(this)) * getLatestPrice()) / 1e18;
        return _USTAmt;
    }

    function _pullRewards() internal override {
        xAnchorBridge.claimRewards();
    }

    function _triggerDepositAction(uint256 _amt) internal override {
        xAnchorBridge.depositStable(address(underlying), _amt);
    }

    function _triggerWithdrawAction(uint256 amtToReturn) internal override {
        xAnchorBridge.redeemStable(address(aUST), amtToReturn);
    }

    // Emergency withdraw in case of previously failed operations
    // Notice that this address is the Terra address of the token
    function emergencyWithdraw(string calldata token) public {
        xAnchorBridge.withdrawAsset(token);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPYUSDImplementation {
    function totalSupply() external view returns (uint256);

    function transfer(address _to, uint256 _value) external returns (bool);

    function balanceOf(address _addr) external view returns (uint256);

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);

    function approve(address _spender, uint256 _value) external returns (bool);

    function increaseApproval(address _spender, uint256 _addedValue) external returns (bool);

    function decreaseApproval(address _spender, uint256 _subtractedValue) external returns (bool);

    function allowance(address _owner, address _spender) external view returns (uint256);

    function proposeOwner(address _proposedOwner) external;

    function disregardProposeOwner() external;

    function claimOwnership() external;

    function reclaimPYUSD() external;

    function pause() external;

    function unpause() external;

    function setAssetProtectionRole(address _newAssetProtectionRole) external;

    function freeze(address _addr) external;

    function unfreeze(address _addr) external;

    function wipeFrozenAddress(address _addr) external;

    function isFrozen(address _addr) external view returns (bool);

    function setSupplyController(address _newSupplyController) external;

    function increaseSupply(uint256 _value) external returns (bool);

    function decreaseSupply(uint256 _value) external returns (bool);

    function isWhitelistedBetaDelegate(address _addr) external view returns (bool);

    function setBetaDelegateWhitelister(address _newWhitelister) external;

    function whitelistBetaDelegate(address _addr) external;

    function unwhitelistBetaDelegate(address _addr) external;
}

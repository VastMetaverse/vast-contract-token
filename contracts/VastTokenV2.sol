// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import "./layerzero/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";

contract VastTokenV2 is
    Initializable,
    ERC20Upgradeable,
    ERC165Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    NonblockingLzAppUpgradeable
{
    mapping(address => bool) private _admins;

    function initialize() public initializer {}

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function _nonblockingLzReceive(
        uint16 __srcChainId,
        bytes memory __srcAddress,
        uint64 __nonce,
        bytes memory __payload
    ) internal virtual override {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

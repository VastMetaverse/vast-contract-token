// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import "./layerzero/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";

import "./extensions/VastAdminUpgradeable.sol";

contract VastToken is
    Initializable,
    ERC20Upgradeable,
    ERC165Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    NonblockingLzAppUpgradeable,
    VastAdminUpgradeable
{
    /**
     * @dev Error handling for forbidden operations.
     */
    error Forbidden();

    /**
     * @dev Emitted when `__amount` tokens are awarded to `__account`.
     */
    event Awarded(address __account, uint256 __amount);

    /**
     * @dev Emitted when `__amount` tokens are burned by `__account`.
     */
    event Burned(address __account, uint256 __amount);

    /**
     * @dev Emitted when `__amount` tokens are redeemed by `__account`.
     */
    event Redeemed(address __account, uint256 __amount);

    /**
     * @dev Emitted when `__amount` tokens are received from `__srcChainId` into the `__toAddress` on the local chain.
     * `__nonce` is the inbound nonce.
     */
    event ReceiveFromChain(
        uint16 indexed __srcChainId,
        bytes indexed __srcAddress,
        address indexed __toAddress,
        uint256 __amount,
        uint64 __nonce
    );

    /**
     * @dev Emitted when `__amount` tokens are moved from the `__sender` to (`__dstChainId`, `__toAddress`)
     * `__nonce` is the outbound nonce
     */
    event SendToChain(
        address indexed __sender,
        uint16 indexed __dstChainId,
        bytes indexed __toAddress,
        uint256 __amount,
        uint64 __nonce
    );

    function initialize(
        string memory __name,
        string memory __symbol,
        address __lzEndpoint
    ) public initializer {
        __ERC20_init(__name, __symbol);
        __NonblockingLzAppUpgradeable_init(__lzEndpoint);
        __Ownable_init();
        __UUPSUpgradeable_init();

        createAdmin(owner());
    }

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
    ) internal virtual override {
        // decode and load the toAddress
        (bytes memory toAddressBytes, uint256 amount) = abi.decode(
            __payload,
            (bytes, uint256)
        );
        address toAddress;
        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }

        _mint(toAddress, amount);

        emit ReceiveFromChain(
            __srcChainId,
            __srcAddress,
            toAddress,
            amount,
            __nonce
        );
    }

    function approve(address, uint256) public virtual override returns (bool) {
        revert Forbidden();
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    function decreaseAllowance(address, uint256)
        public
        virtual
        override
        returns (bool)
    {
        revert Forbidden();
    }

    function increaseAllowance(address, uint256)
        public
        virtual
        override
        returns (bool)
    {
        revert Forbidden();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function transfer(address, uint256) public virtual override returns (bool) {
        revert Forbidden();
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public virtual override returns (bool) {
        revert Forbidden();
    }

    function estimateSendFee(
        uint16 __dstChainId,
        bytes memory __toAddress,
        uint256 __amount,
        bool __useZro,
        bytes memory __adapterParams
    ) public view virtual returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(__toAddress, __amount);
        return
            lzEndpoint.estimateFees(
                __dstChainId,
                address(this),
                payload,
                __useZro,
                __adapterParams
            );
    }

    function bridge(
        address __from,
        uint16 __dstChainId,
        bytes memory __toAddress,
        uint256 __amount,
        address payable __refundAddress,
        address __zroPaymentAddress,
        bytes memory __adapterParams
    ) public payable virtual {
        address sender = _msgSender();

        require(__from == sender, "Not owned.");
        require(
            __adapterParams.length == 0,
            "LzApp: _adapterParams not empty."
        );

        _burn(__from, __amount);

        bytes memory payload = abi.encode(__toAddress, __amount);
        _lzSend(
            __dstChainId,
            payload,
            __refundAddress,
            __zroPaymentAddress,
            __adapterParams
        );

        uint64 nonce = lzEndpoint.getOutboundNonce(__dstChainId, address(this));

        emit SendToChain(__from, __dstChainId, __toAddress, __amount, nonce);
    }

    /**
     * @dev Awards `__amount` to `__account`.
     */
    function award(address __account, uint256 __amount) external onlyOwner {
        _mint(__account, __amount);

        emit Awarded(__account, __amount);
    }

    /**
     * @dev Awards many `__amounts` to many `__accounts`.
     */
    function awardMany(address[] memory __accounts, uint256[] memory __amounts)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < __accounts.length; i++) {
            _mint(__accounts[i], __amounts[i]);

            emit Awarded(__accounts[i], __amounts[i]);
        }
    }

    /**
     * @dev Burns `__amount`.
     */
    function burn(uint256 __amount) external {
        address sender = _msgSender();

        _burn(sender, __amount);

        emit Burned(sender, __amount);
    }

    /**
     * @dev Redeems `__amount` for `__account`.
     */
    function redeem(address __account, uint256 __amount)
        external
        onlyAdmin
        whenNotPaused
    {
        _burn(__account, __amount);

        emit Redeemed(__account, __amount);
    }

    /**
     * @dev Pauses redemption.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses redemption.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

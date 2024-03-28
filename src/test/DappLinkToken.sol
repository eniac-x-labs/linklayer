// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/UUPSUpgradeable.sol";

contract DappLinkToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
     constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __ERC20_init("DappLinkToken", "DPLK");
        __Ownable_init(initialOwner);
        __ERC20Permit_init("DappLinkToken");
        __UUPSUpgradeable_init();

        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}

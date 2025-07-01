// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract BlankERC20 is ERC20, ERC20Permit {
    constructor(address recipient) ERC20("Blank", "BLK") ERC20Permit("Blank") {
        _mint(recipient, 10 ** decimals());
    }

    bool public paused = false;

    function pause() public {
        paused = true;
    }

    function transfer(address to, uint256 value) public override(ERC20) returns (bool) {
        if (!paused) {
            _transfer(msg.sender, to, value);
            return true;
        }
        return false;
    }
}

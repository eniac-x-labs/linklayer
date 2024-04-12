// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./StrategyBase.sol";


contract StrategyBaseUpgrade is StrategyBase {

    function withdraw()external{
      msg.sender.call{value: address(this).balance}("");
    }

}

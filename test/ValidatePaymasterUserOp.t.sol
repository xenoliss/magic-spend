// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "./PaymasterMagicSpendBase.sol";
import "./Validate.t.sol";

contract ValidatePaymasterUserOpTest is PaymasterMagicSpendBaseTest, ValidateTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank(magic.entryPoint());
    }

    function test_revertsIfMaxCostMoreThanRequested() public {
        maxCost = amount + 1;
        vm.expectRevert(abi.encodeWithSelector(MagicSpend.RequestLessThanGasMaxCost.selector, amount, maxCost));
        magic.validatePaymasterUserOp(_getUserOp(), userOpHash, maxCost);
    }

    function test_returnsCorrectly() public {
        (bytes memory context, uint256 validationData) =
            magic.validatePaymasterUserOp(_getUserOp(), userOpHash, maxCost);
        (uint256 withheld, address sender) = abi.decode(context, (uint256, address));
        assertEq(maxCost, withheld);
        assertEq(sender, withdrawer);
        assertEq(uint160(validationData), 0);
        assertEq(uint160(validationData >> 160), expiry);
        assertEq(uint160(validationData >> 160 + 48), 0);
    }

    function test_revertsIfWithdrawAssetNotZero() public {
        asset = address(1);
        vm.expectRevert(abi.encodeWithSelector(MagicSpend.UnsupportedPaymasterAsset.selector, asset));
        magic.validatePaymasterUserOp(_getUserOp(), userOpHash, maxCost);
    }

    function test_returns1sIfWrongSignature() public {
        ownerPrivateKey = ownerPrivateKey + 1;

        (, uint256 validationData) = magic.validatePaymasterUserOp(_getUserOp(), userOpHash, maxCost);
        assertEq(uint160(validationData), 1);
    }

    function test_setsExcess(uint256 amount_, uint256 maxCost_, uint256 actualCost) public {
        vm.assume(maxCost_ <= amount_);
        vm.assume(actualCost <= maxCost_);
        amount = amount_;
        magic.validatePaymasterUserOp(_getUserOp(), userOpHash, maxCost_);
        uint256 expected = amount - maxCost_;
        assertEq(magic.withdrawableFunds(withdrawer), expected);
    }

    function test_doesNotOverwriteExcess(uint256 amount_, uint256 maxCost_, uint256 actualCost) public {
        maxCost_ = bound(maxCost_, 0, amount_);
        actualCost = bound(actualCost, 0, maxCost_);
        uint256 expected = amount_ - maxCost_;
        vm.assume(expected < type(uint256).max / 2);
        amount = amount_;
        magic.validatePaymasterUserOp(_getUserOp(), userOpHash, maxCost_);
        assertEq(magic.withdrawableFunds(withdrawer), expected);
        nonce += 1;
        magic.validatePaymasterUserOp(_getUserOp(), userOpHash, maxCost_);
        assertEq(magic.withdrawableFunds(withdrawer), expected * 2);
    }

    function test_emitsCorrectly(address, uint256 amount_, uint256 nonce_) public override {
        maxCost = amount_;
        super.test_emitsCorrectly(magic.entryPoint(), amount_, nonce_);
    }

    function _validateInvokingCall() internal override {
        magic.validatePaymasterUserOp(_getUserOp(), userOpHash, maxCost);
    }
}

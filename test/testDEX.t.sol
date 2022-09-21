pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ERC20.sol";
import "../src/IERC20.sol";
import "../src/DEX.sol";
import "../src/SwapFactory.sol";

contract MintableToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {

    }

    function mint(address receiver, uint256 value) public {
        super._mint(receiver, value);
    }
}

contract DexTest is Test {
    DEX dex;
    MintableToken tokenX;
    MintableToken tokenY;
    IERC20 lpToken;

    function setUp() public {
        tokenX = new MintableToken("token X", "TX");
        tokenY = new MintableToken("token Y", "TY");
        tokenX.mint(address(this), 100 ether);
        tokenY.mint(address(this), 100 ether);
        SwapFactory swapFactory = new SwapFactory();
        dex = DEX(swapFactory.getpool(address(tokenX), address(tokenY)));            
    }

    function testAddLiquidityBasic() public {
        tokenX.approve(address(dex), 10 ether);
        tokenY.approve(address(dex), 10 ether);
        uint lpTokenAmount1 = dex.addLiquidity(5 ether, 5 ether, 0);
        tokenX.approve(address(dex), 20 ether);
        tokenY.approve(address(dex), 20 ether);
        uint256 lpTokenAmount2 = dex.addLiquidity(20 ether, 20 ether, 0);
        require(lpTokenAmount2 > lpTokenAmount1);
    }

    function testRemoveLiquidityBasic() public {
        address provider = address(0x11223344);
        tokenX.transfer(provider, 10 ether);
        tokenY.transfer(provider, 10 ether);

        vm.startPrank(provider);
        tokenX.approve(address(dex), 10 ether);
        tokenY.approve(address(dex), 10 ether);
        uint lpTokenAmount = dex.addLiquidity(10 ether, 10 ether, 0);
        // uint256 lpBalance = lpToken.balanceOf(provider);
        // uint256 balBefore = tokenX.balanceOf(provider);
        // lpToken.approve(address(dex), 10 ether);
        dex.removeLiquidity(lpTokenAmount, 0, 0);
        // uint256 balAfter = tokenX.balanceOf(provider);
        // assertEq(balAfter, balBefore + 10 ether);
    }

    function testSwapBasic() public {
        address actor1 = address(0xaa);
        address actor2 = address(0xbb);
        tokenX.approve(address(dex), 10 ether);
        tokenY.approve(address(dex), 10 ether);
        uint256 lpTokenAmount = dex.addLiquidity(10 ether, 10 ether, 0);
        tokenX.transfer(actor1, 1 ether);
        vm.startPrank(actor1);
        tokenX.approve(address(dex), 1 ether);
        uint256 tokenYAmountFirst = dex.swap(0.1 ether, 0, 0);
        uint256 tokenYAmountSecond = dex.swap(0.1 ether, 0, 0);
        assert(tokenYAmountFirst > tokenYAmountSecond);
    }
}
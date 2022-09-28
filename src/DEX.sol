// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ERC20.sol";
interface IDEX{
    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount);
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount);
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external;
}

contract DEX is IDEX, ERC20{

    address factory;
    address tokenX;
    address tokenY;

    address[] LPowners;

    uint256 private reserve0;
    uint256 private reserve1;

    constructor() ERC20("GWDEX", "GW") {
        factory = msg.sender;
    }

    function init(address token0, address token1) external  {
        require(factory == msg.sender);

        tokenX = token0;
        tokenY = token1;
    }

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function _update(uint balance0, uint balance1) private {
        reserve0 = uint256(balance0);
        reserve1 = uint256(balance1);
    }

    function calFee(uint256 inputAmount) internal returns(uint256 fee){
        fee = inputAmount / 10;
    }

    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount){
        require(tokenXAmount > 0 || tokenYAmount > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        require(tokenXAmount == 0 || tokenYAmount == 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        
        (uint256 _reserve0, uint256 _reserve1) = getReserves(); //gas save
        (address inToken, address outToken, uint inputAmount, uint256 reserveIn, uint256 reserveOut) = 
            (tokenYAmount == 0) ? (tokenX, tokenY, tokenXAmount, _reserve0, _reserve1) : (tokenY, tokenX, tokenYAmount, _reserve1, _reserve0);

        (reserveIn, reserveOut)  = _swap(inToken, outToken, inputAmount, reserveIn, reserveOut, tokenMinimumOutputAmount);
        (tokenYAmount == 0) ? _update(reserveIn, reserveOut) : _update(reserveOut, reserveIn);
    }

    function _swap(address inToken, address outToken, uint256 inputAmount, uint256 reserveIn, uint256 reserveOut, uint minimum)
        internal returns (uint256 _reserveIn, uint256 _reserveOut){
        uint256 fee = calFee(inputAmount);
        inputAmount += fee;
        uint256 balance = ERC20(inToken).balanceOf(msg.sender);
        require(balance >= inputAmount, 'Over balance');

        uint256 constK = reserveIn * reserveOut;
        uint256 outputAmount = reserveOut - constK / (reserveIn + inputAmount);
        require(outputAmount >= minimum, "lower than minimum output Tokens");

        ERC20(inToken)._transfer(msg.sender ,address(this), inputAmount);
        ERC20(outToken)._transfer(address(this), msg.sender, outputAmount);
        feeProcedure(inToken, fee);
        
        _reserveIn = reserveIn + inputAmount;
        _reserveOut = reserveOut - outputAmount;
    }

    function feeProcedure(address token, uint256 fee) internal {
        for(uint i = 0 ; i < LPowners.length; i++){
            uint earnedAmount = fee * _balances[LPowners[i]] / totalSupply();
            ERC20(token)._transfer(address(this), LPowners[i], earnedAmount);
        }
    }

    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount)
    external returns (uint256 LPTokenAmount){
        (uint256 _reserve0, uint256 _reserve1) = getReserves();

        uint _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            LPTokenAmount = sqrt(tokenXAmount * tokenYAmount);
        //    _mint(address(0), minimumLPTokenAmount); // 풀 비우지 않기 위해 + zero division
        } else {
            LPTokenAmount = min((tokenXAmount * _totalSupply) / _reserve0, (tokenYAmount * _totalSupply) / _reserve1);
            // LPTokenAmount = min(sqrt((tokenXAmount * _totalSupply) / _reserve0), sqrt((tokenYAmount * _totalSupply) / _reserve1));
        }

        require(LPTokenAmount >= minimumLPTokenAmount);
        _mint(msg.sender, LPTokenAmount);
        LPowners.push(msg.sender);

        _update((tokenXAmount + _reserve0), (tokenYAmount + _reserve1));
    }
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external{
        uint liquidity = balanceOf(msg.sender);
        require(liquidity >= LPTokenAmount);

        (uint256 _reserve0, uint256 _reserve1) = getReserves();                            
        uint _totalSupply = totalSupply();

        uint256 amount0 = LPTokenAmount * _reserve0 / _totalSupply;
        uint256 amount1 = LPTokenAmount * _reserve1 / _totalSupply;

        require(amount0 >= minimumTokenXAmount && amount1 >= minimumTokenYAmount);
        _burn(address(this), LPTokenAmount);

        ERC20(tokenX)._transfer(address(this), msg.sender, amount0);
        ERC20(tokenY)._transfer(address(this), msg.sender, amount1);

        _update((_reserve0 - amount0), (_reserve1 - amount1));
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

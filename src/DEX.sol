// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ERC20.sol";

contract DEX is ERC20{
    address factory;
    address tokenX;
    address tokenY;

    uint256 private reserve0;
    uint256 private reserve1;

    constructor(address _tokenX, address _tokenY) ERC20("GWDEX", "GW") {
        require(_tokenX != _tokenY, "DA-DEX: Tokens should be different");

        tokenX = _tokenX;
        tokenY = _tokenY;
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

    function _update() private {
        reserve0 = ERC20(tokenX).balanceOf(address(this));
        reserve1 = ERC20(tokenY).balanceOf(address(this));
    }

    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount){
        require(tokenXAmount == 0 || tokenYAmount == 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        
        (uint256 _reserve0, uint256 _reserve1) = getReserves(); //gas save
        (address inToken, address outToken, uint inputAmount, uint256 reserveIn, uint256 reserveOut) = 
            (tokenYAmount == 0) ? (tokenX, tokenY, tokenXAmount, _reserve0, _reserve1) : (tokenY, tokenX, tokenYAmount, _reserve1, _reserve0);

        outputAmount = _swap(inToken, outToken, inputAmount, reserveIn, reserveOut, tokenMinimumOutputAmount);
        _update();
    }

    function _swap(address inToken, address outToken, uint256 inputAmount, uint256 reserveIn, uint256 reserveOut, uint minimum)
        internal returns (uint256 outputAmount){
        uint256 IntokenBalance = ERC20(inToken).balanceOf(msg.sender);
        require(IntokenBalance >= inputAmount, 'balance exceeds');

        uint256 constK = reserveIn * reserveOut;
        uint256 calNum = constK / (reserveIn + inputAmount);
        if(constK % (reserveIn + inputAmount) != 0)
            calNum += 1;
        outputAmount = (reserveOut - calNum) * 999 / 1000;
        require(outputAmount >= minimum, "lower than minimum output Tokens");

        ERC20(inToken).transferFrom(msg.sender, address(this), inputAmount);
        ERC20(outToken).transfer(msg.sender, outputAmount);
    }

    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount)
    external returns (uint256 LPTokenAmount){
        require(tokenXAmount!=0 && tokenYAmount !=0);
        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        uint _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            LPTokenAmount = sqrt(tokenXAmount * tokenYAmount);
        //    _mint(address(0), 10000); // 풀 비우지 않기 위해 + zero division
        } else {
            LPTokenAmount = min((tokenXAmount * _totalSupply) / _reserve0, (tokenYAmount * _totalSupply) / _reserve1);
            // LPTokenAmount = min(sqrt((tokenXAmount * _totalSupply) / _reserve0), sqrt((tokenYAmount * _totalSupply) / _reserve1));
        }

        require(LPTokenAmount >= minimumLPTokenAmount);
        ERC20(tokenX).transferFrom(msg.sender, address(this), tokenXAmount);
        ERC20(tokenY).transferFrom(msg.sender, address(this), tokenYAmount);
        _mint(msg.sender, LPTokenAmount);

       _update();
    }
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount)
    external returns (uint256 transferX, uint256 transferY){
        uint liquidity = balanceOf(msg.sender);
        require(liquidity >= LPTokenAmount);

        (uint256 _reserve0, uint256 _reserve1) = getReserves();                            
        uint _totalSupply = totalSupply();

        transferX = LPTokenAmount * _reserve0 / _totalSupply;
        transferY = LPTokenAmount * _reserve1 / _totalSupply;

        require(transferX >= minimumTokenXAmount && transferY >= minimumTokenYAmount);
        _burn(msg.sender, LPTokenAmount);

        ERC20(tokenX).transfer(msg.sender, transferX);
        ERC20(tokenY).transfer(msg.sender, transferY);

        _update();
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
}

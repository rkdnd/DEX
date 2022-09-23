// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ERC20.sol";

/*
        CPMM (xy=k) 방식의 AMM을 사용하는 DEX를 구현하세요.

        Swap :
            Pool 생성 시 지정된 두 종류의 토큰을 서로 교환할 수 있어야 합니다.
            Input 토큰과 Input 수량, 최소 Output 요구량을 받아서 Output 토큰으로 바꿔주고 최소 요구량에 미달할 경우 revert 해야합니다.
            수수료는 0.1%로 하세요.

        Add / Remove Liquidity :
            ERC-20 기반 LP 토큰을 사용해야 합니다.
            수수료 수입과 Pool에 기부된 금액을 제외하고는 더 많은 토큰을 회수할 수 있는 취약점이 없어야 합니다.
            Concentrated Liquidity는 필요 없습니다.
*/
interface IDEX{
    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount);
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount);
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external;
}

contract DEX is IDEX, ERC20{
    // uint public constant MINIMUM_LIQUIDITY = 10**3;
    // bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address factory;
    address tokenX;
    address tokenY;

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

    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount){
        require(tokenXAmount > 0 || tokenYAmount > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        
        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        (address inToken, address outToken, uint inputAmount, uint256 reserveTo, uint256 reserveGet) = 
            (tokenYAmount == 0) ? (tokenX, tokenY, tokenXAmount, _reserve0, _reserve1) : (tokenY, tokenX, tokenYAmount, _reserve1, _reserve0);

        uint256 balance = ERC20(inToken).balanceOf(msg.sender);
        require(balance >= inputAmount, 'Over balances');

        (outputAmount, reserveTo, reserveGet)  = _swap(inToken, outToken, inputAmount, reserveTo, reserveGet, tokenMinimumOutputAmount);
        (tokenYAmount == 0) ? _update(reserveTo, reserveGet) : _update(reserveGet, reserveTo);
    }

    function _swap(address inToken, address outToken, uint256 inputAmount, uint256 reserveTo, uint256 reserveGet, uint minimum) internal returns (uint256 outputAmount, uint112 _reserveTo, uint112 _reserveGet){
        uint256 constK = (reserveTo / 1000) * (reserveGet / 1000);

        outputAmount = reserveGet - constK / (reserveTo + inputAmount);
        require(outputAmount >= minimum, "lower than minimum output Tokens");

        uint256 _reserveTo = reserveTo + inputAmount;
        uint256 _reserveGet = reserveGet - outputAmount;

        _transfer(inToken, address(this), inputAmount);
        _transfer(outToken, msg.sender ,outputAmount);
    }

    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount){
        uint balance0 = ERC20(tokenX).balanceOf(address(this));
        uint balance1 = ERC20(tokenY).balanceOf(address(this));
        require(tokenXAmount <= balance0 && tokenYAmount <= balance1, 'tokens out of owned') ;

        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        uint _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            LPTokenAmount = sqrt(tokenXAmount * tokenYAmount) - minimumLPTokenAmount;
           _mint(address(0), minimumLPTokenAmount); // 풀 비우지 않기 위해 + zero division
        } else {
            LPTokenAmount = min((tokenXAmount * _totalSupply) / _reserve0, (tokenYAmount * _totalSupply) / _reserve1);
        }

        require(LPTokenAmount > 0);
        _mint(address(this), LPTokenAmount);

        _update((tokenXAmount + _reserve0), (tokenYAmount + _reserve1));
    }
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external{
        uint liquidity = balanceOf(address(this));
        require(liquidity >= LPTokenAmount);
        (uint256 _reserve0, uint256 _reserve1) = getReserves();                            
        uint balance0 = ERC20(tokenX).balanceOf(address(this));
        uint balance1 = ERC20(tokenY).balanceOf(address(this));
        uint _totalSupply = totalSupply();

        uint256 amount0 = LPTokenAmount * minimumTokenXAmount / _totalSupply;
        uint256 amount1 = LPTokenAmount * minimumTokenYAmount / _totalSupply;

        //mintfee
        require(amount0 > 0 && amount1 > 0);
        _burn(address(this), LPTokenAmount);

        _transfer(tokenX, address(this), amount0);
        _transfer(tokenY, address(this), amount1);

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

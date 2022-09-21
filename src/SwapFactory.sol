pragma solidity ^0.8.13;

import "./DEX.sol";
contract SwapFactory{
    mapping(address => mapping(address => address)) public getPool; //mapping 0로 초기화?
    address[] public _pools;

    function createPool(address tokenX, address tokenY) public returns (address pAddress){
        require(tokenX != tokenY);
        (address token0, address token1) = tokenX < tokenY ? (tokenX, tokenY) : (tokenY, tokenX); 
        require(token0 != address(0) || token1 != address(0)); //왜 token0 만 address(0) 검사?
        require(getPool[token0][token1] == address(0), "pool exist");

        DEX poolAddress = new DEX();
        poolAddress.init(token0, token1);
        pAddress = address(poolAddress);

        getPool[token0][token1] = pAddress;
        getPool[token1][token0] = pAddress;
        _pools.push(pAddress);
    }

    function getpool(address token0, address token1) public returns (address poolAddress){
        if(getPool[token0][token1] == address(0)){
            return createPool(token0, token1);
        }else{
            return getPool[token0][token1];
        }
    }
}

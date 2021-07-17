//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

interface IBetToken {

    /**
     * Functions for public variables
     */
    function totalHolders() external returns (uint256);
    function predictionMarket() external returns (address);

    /**
     * Functions overridden in BetToken
     */
    function mint(address _to, uint256 _value) external;

    function burn(address _from, uint256 _value) external;

    function burnAll(address _from) external;

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom( address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * Functions of Pausable
     */
    function paused() external view returns (bool);
    
    /**
     * Functions of ERC20
     */
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view  returns (uint8);
    
    /**
     * Functions of IERC20
     */
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}
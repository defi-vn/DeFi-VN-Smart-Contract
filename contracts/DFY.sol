pragma solidity ^0.7.0;

import "@vittominacori/erc20-token/contracts/ERC20Base.sol";

contract DFY is ERC20Base {

    constructor (
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 cap,
        uint256 initialSupply,
        bool transferEnabled
    ) ERC20Base(name, symbol, decimals, cap, initialSupply, transferEnabled) {}
}

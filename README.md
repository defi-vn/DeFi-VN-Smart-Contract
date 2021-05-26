# DeFi VN Contracts

These are the Solidity contracts for the DFY token and https://defi.vn.

You can get started like:

```bash
git clone https://github.com/defi-vn/DeFi-VN-Smart-Contract
npm i
```

Generally, we use a text editor like Visual Studio code for editing and then we deploy using Remix.


1st - Flatten Solidity source code by Truffle Flattener
truffle-flattener contracts\DFY.sol > FlattenedDFY2.0.sol

2nd - Fix flattened source code duplicated
	// SPDX-License-Identifier: MIT
	// File: @openzeppelin\contracts\token\ERC20\IERC20.sol
	// File: @openzeppelin\contracts\utils\Address.sol
	// File: @openzeppelin\contracts\token\ERC20\ERC20.sol
	// File: node_modules\@openzeppelin\contracts\introspection\IERC165.sol
	// File: @openzeppelin\contracts\math\SafeMath.sol

Compile with Solidity 0.7.0+commit.9e61f92b

# Smart Contract Deployed
Testnet: https://testnet.bscscan.com/address/0x4741Ce2aE675357B3A882E9f6d460805Fb618D51
Mainnet: https://bscscan.com/token/0xD98560689C6e748DC37bc410B4d3096B1aA3D8C2
Treasure contract address: https://bscscan.com/address/0xbd0c5b8904e8c8b28740642c766ad132f4a9a0a3
Treasure timelock: 18/12/2025 5:00pm UTC

# Mirror contract
1st - Add Minter Role
2nd - Build contract by truffle
3rd - Read holders
4th - Assign Minter
5th - Create transaction
6th - Run

# License
 
The MIT License (MIT)

Copyright (c) 2015 Chris Kibble

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

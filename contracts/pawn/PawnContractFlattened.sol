// Sources flattened with hardhat v2.3.0 https://hardhat.org

// File @openzeppelin/contracts/utils/Context.sol@v4.1.0

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


// File @openzeppelin/contracts/access/Ownable.sol@v4.1.0

pragma solidity ^0.8.4;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


// File @openzeppelin/contracts/security/Pausable.sol@v4.1.0

pragma solidity ^0.8.4;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor () {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


// File @openzeppelin/contracts/security/ReentrancyGuard.sol@v4.1.0

pragma solidity ^0.8.4;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v4.1.0

pragma solidity ^0.8.4;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File @openzeppelin/contracts/utils/Address.sol@v4.1.0

pragma solidity ^0.8.4;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// File @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol@v4.1.0

pragma solidity ^0.8.4;


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol@v4.1.0

pragma solidity ^0.8.4;

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// File @openzeppelin/contracts/token/ERC20/ERC20.sol@v4.1.0

pragma solidity ^0.8.4;



/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The defaut value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}


// File contracts/pawn/PawnContract.sol

pragma solidity ^0.8.4;
contract PawnContract is Ownable, Pausable, ReentrancyGuard {
    uint256 public numberCollaterals;
    uint256 public numberOffers;
    uint256 public numberContracts;
    uint256 public numberPaymentHistory;
    uint256 public numberPawnShopPackages;

    using SafeERC20 for ERC20;

    enum CollateralStatus {OPEN, DOING, COMPLETED, CANCEL}
    struct Collateral {
        address owner;
        uint256 amount;
        address collateralAddress;
        address loanAsset;
        uint256 expectedDurationQty;
        uint256 expectedDurationType;
        CollateralStatus status;
    }

    enum PawnShopPackageStatus {ACTIVE, INACTIVE}
    enum PawnShopPackageType {AUTO, SEMI_AUTO}

    struct Range {
        uint256 lowerBound;
        uint256 upperBound;
    }

    struct PawnShopPackage {
        address owner;
        PawnShopPackageStatus status;
        PawnShopPackageType packageType;
        address loanToken;
        Range loanAmountRange;
        address[] collateralAcceptance;
        uint256 interest;
        uint256 durationType;
        Range durationRange;
        address repaymentAsset;
        uint256 repaymentCycleType;
        uint256 loanToValue;
        uint256 loanToValueLiquidationThreshold;
    }

    enum OfferStatus {PENDING, ACCEPTED, COMPLETED, CANCEL}
    enum RepaymentCycleType {WEEK, MONTH}
    enum LoanDurationType {WEEK, MONTH}
    struct Offer {
        address owner;
        uint256 collateralId;
        address repaymentAsset;
        uint256 loanAmount;
        uint256 interest;
        uint256 duration;
        OfferStatus status;
        LoanDurationType loanDurationType;
        RepaymentCycleType repaymentCycleType;
        uint256 fines;
        uint256 risk;
    }

    enum ContractStatus {ACTIVE, COMPLETED}

    struct Contract {
        uint256 collateralId;
        uint256 offerId;
        uint256 pawnShopPackageId;
        uint256 currentRepaymentPhase;
        uint256 penalty;
        ContractStatus status;
        uint256 createdAt;
    }

    struct PaymentHistory {
        uint256 contractId;
        address payerAddress;
        uint256 repaymentPhase;
        uint256 payForLoan;
        uint256 payForInterest;
        uint256 payForFines;
        address paymentToken;
        uint256 createAt;
    }

    struct RepaymentPhase {
        uint256 remainingLoan;
        uint256 remainingInterest;
        uint256 remainingFines;
        uint256 paidForInterest;
        uint256 paidForLoan;
        uint256 paidForFines;
        uint256 createdAt;
        uint256 expiration;
    }

    mapping (uint256 => Offer) public offers;
    mapping (uint256 => Collateral) public collaterals;
    mapping (uint256 => PawnShopPackage) public pawnShopPackages;
    mapping (uint256 => Contract) public contracts;
    mapping (uint256 => PaymentHistory) public paymentHistories;
    mapping (uint256 => mapping(uint256 => bool)) public pawnShopPackageSubmittedCollaterals;
    mapping (uint256 => mapping(uint256 => bool)) public pawnShopPackageActiveContracts;
    mapping (uint256 => mapping(uint256 => RepaymentPhase)) public repaymentPhases;
    mapping (address => uint256) whitelistCollateral;
    mapping (address => mapping(uint256 => uint256)) public lastOffer;
    mapping (address => uint256) systemFee;

    address public operator;
    uint256 public penalty;
    uint256 public ZOOM;
    bool public initialized = false;
    address coldWallet;
    address public admin;

    event CreatePawnShopPackage(
        uint256 packageId,
        PawnShopPackage data
    );

    event ChangeStatusPawnShopPackage(
        uint256 packageId,
        PawnShopPackageStatus status         
    );

    event SubmitPawnShopPackage(
        uint256 packageId,
        uint256 collateralId
    );

    event CreateCollateral(
        uint256 collateralId,
        uint256 amount,
        address walletAddress,
        address cryptoAsset,
        address expectedCryptoAssetSymbol,
        uint256 expectedDurationQty,
        uint256 expectedDurationType
    );

    event WithdrawCollateral(
        uint256 collateralId,
        address collateralOwner
    );

    event CreateOffer(
        uint256 offerId,
        uint256 collateralId,
        address offerOwner,
        address repaymentAsset,
        address supplyCurrencyAsset,
        uint256 loanAmount,
        uint256 duration,
        uint256 interest,
        uint256 loanDurationType,
        uint256 repaymentCycleType,
        uint256 fines,
        uint256 risk
    );

    event CancelOffer(
        uint256 offerId,
        address offerOwner
    );

    event AcceptOffer(
        address fromAddress,
        uint256 contractId,
        uint256 collateralId,
        uint256 offerId,
        address offerOwner,
        address collateralOwner,
        uint256 startContract,
        uint256 endContract
    );

    event Repayment(
        uint256 paymentHistory,
        uint256 contractId,
        uint256 phase,
        address paymentToken,
        uint256 payForInterest,
        uint256 payForLoan,
        uint256 payForFines
    );

    event Liquidity(
        address transferTo,
        uint256 amount,
        uint256 status
    );

    modifier notInitialized() {
        require(!initialized, "initialized");
        _;
    }

    /**
     * @dev initialize function
     * @param _zoom is coefficient used to represent risk params
     * @param _penalty is number of overdue debt payments
     */

    function initialize(
        uint256 _zoom,
        uint256 _penalty,
        address _coldWallet
    ) external notInitialized {
        ZOOM = _zoom;
        penalty = _penalty;
        coldWallet = _coldWallet;
        admin = msg.sender;
        initialized = true;
    }

    function setOperator(address _newOperator) onlyAdmin external {
        operator = _newOperator;
    }

    function pause() onlyOperator external {
        _pause();
    }

    function unPause() onlyOperator external {
        _unpause();
    }

    /**
    * @dev set fee for each token
    * @param _token is address of token
    * @param _fee is amount of tokens to pay for the transaction
    */

    function setSystemFee(address _token, uint256 _fee) external onlyOperator {
        systemFee[_token] = _fee;
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "caller is not the operator");
        _;
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "caller is not the admin");
        _;
    }

    function setWhitelistCollateral(address _token, uint256 _status) external onlyOperator{
        whitelistCollateral[_token] = _status;
    }

    function createPawnShopPackage(
        PawnShopPackageType _packageType,
        address _loanToken,
        Range calldata _loanAmountRange,
        address[] calldata _collateralAcceptance,
        uint256 _interest,
        uint256 _durationType,
        Range calldata _durationRange,
        address _repaymentAsset,
        uint256 _repaymentCycleType,
        uint256 _loanToValue,
        uint256 _loanToValueLiquidationThreshold
    ) external whenNotPaused
    returns (uint256 _idx)
    {
        _idx = numberPawnShopPackages;

        // TODO : Validataion logic: whitelist collateral, ranges must have upper greater than lower, duration type
        for (uint256 i = 0; i < _collateralAcceptance.length; i++) {
            require(whitelistCollateral[_collateralAcceptance[i]] == 1, 'not-support-collateral');
        }

        require(_loanAmountRange.lowerBound < _loanAmountRange.upperBound, 'loan-range-invalid');
        require(_durationRange.lowerBound < _durationRange.upperBound, 'duration-range-invalid');
        require(_durationType == uint256(LoanDurationType.MONTH) || _durationType == uint256(LoanDurationType.WEEK), 'duration-type-invalid');

        //create new collateral
        PawnShopPackage storage newPackage = pawnShopPackages[_idx];
        newPackage.owner = msg.sender;
        newPackage.status = PawnShopPackageStatus.ACTIVE;
        newPackage.packageType = _packageType;
        newPackage.loanToken = _loanToken;
        newPackage.loanAmountRange = _loanAmountRange;
        newPackage.collateralAcceptance = _collateralAcceptance;
        newPackage.interest = _interest;
        newPackage.durationType = _durationType;
        newPackage.durationRange = _durationRange;
        newPackage.repaymentAsset = _repaymentAsset;
        newPackage.repaymentCycleType = _repaymentCycleType;
        newPackage.loanToValue = _loanToValue;
        newPackage.loanToValueLiquidationThreshold = _loanToValueLiquidationThreshold;

        ++numberPawnShopPackages;
        emit CreatePawnShopPackage(
            _idx, 
            newPackage
        );
    }

    function activePawnShopPackage(uint256 _packageId)
    external whenNotPaused
    {
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.owner == msg.sender, 'not-owner-of-this-package');
        require(pawnShopPackage.status == PawnShopPackageStatus.INACTIVE, 'package-not-inactive');

        pawnShopPackage.status = PawnShopPackageStatus.ACTIVE;
        emit ChangeStatusPawnShopPackage(_packageId, PawnShopPackageStatus.ACTIVE);
    }

    function deactivePawnShopPackage(uint256 _packageId)
    external
    {
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.owner == msg.sender, 'not-owner-of-this-package');
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, 'package-not-active');

        pawnShopPackage.status = PawnShopPackageStatus.INACTIVE;
        emit ChangeStatusPawnShopPackage(_packageId, PawnShopPackageStatus.INACTIVE);
    }

    /**
    * @dev create Collateral function, collateral will be stored in this contract
    * @param _collateralAddress is address of collateral
    * @param _packageId is id of pawn shop package
    * @param _amount is amount of token
    * @param _loanAsset is address of loan token
    * @param _expectedDurationQty is expected duration
    * @param _expectedDurationType is expected duration type
    */
    function createCollateral(
        address _collateralAddress,
        int256 _packageId,
        uint256 _amount,
        address _loanAsset,
        uint256 _expectedDurationQty,
        uint256 _expectedDurationType
    ) external whenNotPaused payable
    returns (uint256 _idx)
    {
        //check whitelist collateral token
        require(whitelistCollateral[_collateralAddress] == 1, 'not-support-collateral');

        if (_collateralAddress != address(0)) {
            // transfer to this contract
            uint256 preCollateralBalance = ERC20(_collateralAddress).balanceOf(address(this));
            ERC20(_collateralAddress).safeTransferFrom(msg.sender, address(this), _amount);
            ERC20(_collateralAddress).safeTransferFrom(msg.sender, address(this), systemFee[_collateralAddress]);
            require(ERC20(_collateralAddress).balanceOf(address(this)) - preCollateralBalance == _amount + systemFee[_collateralAddress], 'not-enough-collateral');
        } else {
            _amount = msg.value;
        }
        //id of collateral
        _idx = numberCollaterals;

        //create new collateral
        Collateral storage newCollateral = collaterals[_idx];
        newCollateral.owner = msg.sender;
        newCollateral.amount = _amount;
        newCollateral.collateralAddress = _collateralAddress;
        newCollateral.loanAsset = _loanAsset;
        newCollateral.status = CollateralStatus.OPEN;
        newCollateral.expectedDurationQty = _expectedDurationQty;
        newCollateral.expectedDurationType = _expectedDurationType;

        ++numberCollaterals;

        emit CreateCollateral(_idx, _amount, msg.sender, _collateralAddress, _loanAsset, _expectedDurationQty, _expectedDurationType);

        if (_packageId >= 0) {
            //package must active
            PawnShopPackage storage pawnShopPackage = pawnShopPackages[uint256(_packageId)];
            require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, 'package-not-support');
            pawnShopPackageSubmittedCollaterals[uint256(_packageId)][_idx] = true;
            emit SubmitPawnShopPackage(uint256(_packageId), _idx);
        }
    }

    /**
    * @dev Submit Collateral to Package function, collateral will be submit to pawnshop package
    * @param _collateralId is id of collateral
    * @param _packageId is id of pawn shop package
    */
    function submitCollateralToPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) external whenNotPaused
    {
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.owner == msg.sender, 'not-owner-of-collateral');
        require(collateral.status == CollateralStatus.OPEN, 'collateral-not-open');
        
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, 'package-not-open');
        
        pawnShopPackageSubmittedCollaterals[_packageId][_collateralId] = true;
        emit SubmitPawnShopPackage(_packageId, _collateralId);
    }

    /**
    * @dev create Collateral function, collateral will be stored in this contract
    * @param _collateralId is id of collateral
    * @param _repaymentAsset is address of repayment token
    * @param _duration is duration of this offer
    * @param _loanDurationType is type for calculating loan duration
    * @param _repaymentCycleType is type for calculating repayment cycle
    * @param _fines the amount payable for an overdue payment
    * @param _risk is ratio of assets to be liquidated
    */

    function createOffer(
        uint256 _collateralId,
        address _repaymentAsset,
        uint256 _loanAmount,
        uint256 _duration,
        uint256 _interest,
        uint256 _loanDurationType,
        uint256 _repaymentCycleType,
        uint256 _fines,
        uint256 _risk
    )
    external whenNotPaused
    returns (uint256 _idx)
    {
        // each address can create only 1 offer
        Collateral memory collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.OPEN, 'collateral-not-open');

        _idx = numberOffers;
        Offer storage newOffer = offers[_idx];
        newOffer.collateralId = _collateralId;
        newOffer.owner = msg.sender;
        newOffer.repaymentAsset = _repaymentAsset;
        newOffer.loanAmount = _loanAmount;
        newOffer.duration = _duration;
        newOffer.interest = _interest;
        newOffer.loanDurationType = LoanDurationType(_loanDurationType);
        newOffer.repaymentCycleType = RepaymentCycleType(_repaymentCycleType);
        newOffer.fines = _fines;
        newOffer.risk = _risk;
        newOffer.status = OfferStatus.PENDING;
        ++numberOffers;


        emit CreateOffer(_idx, _collateralId, msg.sender, _repaymentAsset, collateral.loanAsset,
            _loanAmount, _duration, _interest, _loanDurationType, _repaymentCycleType, _fines, _risk);
    }

    /**
    * @dev cancel offer function, used for cancel offer
    * @param  _offerId is id of offer
    */
    function cancelOffer(uint256 _offerId) external {
        Offer storage offer = offers[_offerId];
        require(offer.owner == msg.sender, 'not-owner-of-offer');
        require(offer.status == OfferStatus.PENDING, 'offer-executed');
        offer.status = OfferStatus.CANCEL;
        emit CancelOffer(_offerId, msg.sender);
    }

    /**
    * @dev cancel collateral function and return back collateral
    * @param  _collateralId is id of collateral
    */
    function withdrawCollateral(uint256 _collateralId) external {
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.owner == msg.sender, 'not-owner-of-this-collateral');
        require(collateral.status == CollateralStatus.OPEN, 'collateral-not-open');
        for (uint256 i = 0; i < numberOffers; i++) {
            if (offers[i].collateralId == _collateralId) {
                offers[i].status = OfferStatus.CANCEL;
                emit CancelOffer(i, offers[i].owner);
            }
        }
        if (collateral.collateralAddress != address(0)) {
            // transfer collateral to collateral's owner
            require(ERC20(collateral.collateralAddress).transfer(collateral.owner, collateral.amount), 'transfer-collateral-fail');
        } else {
            payable(collateral.owner).transfer(collateral.amount);
        }
        collateral.status = CollateralStatus.CANCEL;
        emit WithdrawCollateral(_collateralId, msg.sender);
    }

    function calculationOfferDuration(uint256 _offerId)
    internal view
    returns (uint256 duration)
    {
        Offer memory offer = offers[_offerId];
        if (offer.loanDurationType == LoanDurationType.WEEK) {
            duration = 7 * 24 * 3600 * offer.duration;
        } else {
            duration = 30 * 24 * 3600 * offer.duration;
        }
    }


    /**
        * @dev accept offer and create contract between collateral and offer
        * @param  _collateralId is id of collateral
        * @param  _offerId is id of offer
        */
    function acceptOffer(uint256 _collateralId, uint256 _offerId) external whenNotPaused {
        Offer storage offer = offers[_offerId];
        Collateral storage collateral = collaterals[_collateralId];
        require(msg.sender == collateral.owner, 'not-collateral-owner');
        require(_collateralId == offer.collateralId, 'collateralId-not-match-offerId');
        require(collateral.status == CollateralStatus.OPEN, '-collateral-not-open');
        require(offer.status == OfferStatus.PENDING, 'offer-unavailable');

        //transfer loan asset to collateral owner
        ERC20(collateral.loanAsset).safeTransferFrom(offer.owner, collateral.owner, offer.loanAmount);
        //transfer systemFee to this contract
        ERC20(collateral.loanAsset).safeTransferFrom(offer.owner, address(this), systemFee[collateral.loanAsset]);

        uint256 contractId = createContract(_collateralId, _offerId);
        //change status of offer and collateral
        offer.status = OfferStatus.ACCEPTED;
        collateral.status = CollateralStatus.DOING;
        for (uint256 i = 0; i < numberOffers; i++) {
            if (offers[i].collateralId == _collateralId && _offerId != i) {
                offers[i].status = OfferStatus.CANCEL;
                emit CancelOffer(i, offers[i].owner);
            }
        }

        emit AcceptOffer(msg.sender, contractId, _collateralId, _offerId, offer.owner, collateral.owner, block.timestamp, block.timestamp + calculationOfferDuration(_offerId));
    }


    /**
        * @dev create contract between collateral and offer
        * @param  _collateralId is id of collateral
        * @param  _offerId is id of offer
        */

    function createContract (
        uint256 _collateralId,
        uint256 _offerId
    )
    internal
    returns (uint256 _idx)
    {
        _idx = numberContracts;
        Contract storage newContract = contracts[_idx];
        newContract.collateralId = _collateralId;
        newContract.status = ContractStatus.ACTIVE;
        newContract.offerId = _offerId;
        newContract.createdAt = block.timestamp;
        newContract.currentRepaymentPhase = 0;
        ++numberContracts;
    }


    /**
        * @dev repayment for pawn contract
        * @param  _contractId is id contract
        */

    function repayment(
        uint256 _contractId,
        uint256 _payForInterest,
        uint256 _payForLoan,
        uint256 _payForFines
    )
    external
    {
        Contract storage _contract = contracts[_contractId];
        RepaymentPhase storage repaymentPhase = repaymentPhases[_contractId][_contract.currentRepaymentPhase];
        Offer storage offer = offers[_contract.offerId];

        require(_contract.status == ContractStatus.ACTIVE, 'contract-inactive');
        require(block.timestamp <= repaymentPhase.expiration, 'repayment-phase-expired');

        if (_payForInterest > repaymentPhase.remainingInterest) {
            _payForInterest = repaymentPhase.remainingInterest;
        }
        if (_payForLoan > repaymentPhase.remainingLoan) {
            _payForLoan = repaymentPhase.remainingLoan;
        }
        if (_payForFines > repaymentPhase.remainingFines) {
            _payForFines = repaymentPhase.remainingFines;
        }
        repaymentPhase.remainingInterest -= _payForInterest;
        repaymentPhase.remainingLoan -= _payForLoan;
        repaymentPhase.remainingFines -= _payForFines;
        repaymentPhase.paidForInterest += _payForInterest;
        repaymentPhase.paidForLoan += _payForLoan;
        repaymentPhase.paidForFines += _payForFines;

        ERC20(offer.repaymentAsset).safeTransferFrom(msg.sender, offer.owner, _payForInterest);
        ERC20(offer.repaymentAsset).safeTransferFrom(msg.sender, offer.owner, _payForLoan);
        ERC20(offer.repaymentAsset).safeTransferFrom(msg.sender, offer.owner, _payForFines);

        //the borrower has paid off all the debt
        if (repaymentPhase.remainingInterest + repaymentPhase.remainingLoan+ repaymentPhase.remainingFines== 0) {
            executeLiquidity(_contractId);
        }
        uint256 historyId = createPaymentHistory(_contractId, msg.sender, offer.repaymentAsset, _payForLoan, _payForInterest, _payForFines);
        emit Repayment(historyId, _contractId, _contract.currentRepaymentPhase, offer.repaymentAsset, _payForLoan, _payForInterest, _payForFines);
    }

    /**
        * @dev create payment history function
        */

    function createPaymentHistory(
        uint256 _contractId,
        address _payerAddress,
        address _paymentToken,
        uint256 _payForLoan,
        uint256 _payForInterest,
        uint256 _payForFines
    )
    internal
    returns (uint256 _idx)
    {
        _idx = numberPaymentHistory;
        PaymentHistory storage payment = paymentHistories[_idx];
        payment.contractId = _contractId;
        payment.paymentToken = _paymentToken;
        payment.payerAddress = _payerAddress;
        payment.payForInterest = _payForInterest;
        payment.payForLoan = _payForLoan;
        payment.payForFines = _payForFines;
        payment.createAt = block.timestamp;

        ++numberPaymentHistory;
    }

    /**
       * @dev executeLiquidity is function used for asset liquidation
       * @param  _contractId is id contract
       */

    function executeLiquidity(uint256 _contractId)
    internal
    {
        Contract storage _contract = contracts[_contractId];
        Offer storage offer = offers[_contract.offerId];
        Collateral storage collateral = collaterals[_contract.collateralId];
        //get current status of repayment phase
        RepaymentPhase memory repaymentPhase = repaymentPhases[_contractId][_contract.currentRepaymentPhase];

        //the borrower has paid off all the debt
        if (repaymentPhase.remainingInterest + repaymentPhase.remainingLoan + repaymentPhase.remainingFines == 0) {
            //transfer collateral asset back to collateral's owner
            if (collateral.collateralAddress != address(0)) {
                IERC20(collateral.collateralAddress).transfer(collateral.owner, collateral.amount);
            } else {
                payable(collateral.owner).transfer(collateral.amount);
            }
            emit Liquidity(collateral.owner, collateral.amount, 1);
        } else {
            //the borrower hasn't paid off all the debt
            if (collateral.collateralAddress != address(0)) { // transfer collateral to offer's owner
                IERC20(collateral.collateralAddress).transfer(offer.owner, collateral.amount);
            } else {
                payable(offer.owner).transfer(collateral.amount);
            }
            emit Liquidity(offer.owner, collateral.amount, 0);
        }

        //change status of contract, collateral, offer
        _contract.status = ContractStatus.COMPLETED;
        collateral.status = CollateralStatus.COMPLETED;
        offer.status = OfferStatus.COMPLETED;
    }

    /**
      * @dev createRepaymentPhase is the function for Admin to calculate the amount of remaining debt as well as the interest
      * @param  _expiration is the time that the repayment phase will end
      */
    function createRepaymentPhase(
        uint256 _contractId,
        uint256 _remainingLoan,
        uint256 _remainingInterest,
        uint256 _remainingFines,
        uint256 _penalty,
        uint256 _expiration
    )
    external onlyOperator
    whenNotPaused
    {
        Contract storage _contract = contracts[_contractId];
        require(_contract.status == ContractStatus.ACTIVE, 'Contract inactive');
        if (_penalty > penalty) {
            executeLiquidity(_contractId);
        }
        _contract.penalty = _penalty;
        RepaymentPhase storage repaymentPhase = repaymentPhases[_contractId][_contract.currentRepaymentPhase];
        repaymentPhase.remainingLoan = _remainingLoan;
        repaymentPhase.remainingInterest = _remainingInterest;
        repaymentPhase.remainingFines = _remainingFines;
        repaymentPhase.paidForInterest = 0;
        repaymentPhase.paidForLoan = 0;
        repaymentPhase.paidForFines = 0;
        repaymentPhase.expiration = _expiration;
    }

    /**
     * @dev liquidity is the function for Admin execute contract liquidation
     * @param  _contractId is the id of contract
     */
    function liquidity(uint256 _contractId)
    external onlyOperator
    whenNotPaused {
        executeLiquidity(_contractId);
    }


    /**
    * @dev emergencyWithdraw is a function to be used only in emergencies
    * @param  _token is the address of withdrawal token
    */

    function emergencyWithdraw(address _token)
    external onlyAdmin
    whenPaused {
        if (_token == address (0)) {
            payable(coldWallet).transfer(address(this).balance);
        } else {
            IERC20(_token).transfer(coldWallet, IERC20(_token).balanceOf(address(this)));
        }
    }
}

pragma solidity ^0.7.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract DFY1155 is Ownable, Pausable, ERC1155 {
    using SafeMath for uint256;

    mapping(uint256 => string) public tokenUri;
    mapping(uint256 => address) public creators;
    mapping(address => bool) public whitelistAdmins;

    uint256 public currentTokenID = 0;

    bool public needApprove;
    enum NFTStatus {PENDING, APPROVED, REJECTED}
    struct NFT {
        address owner;
        uint256 maxSupply;
        string uri;
        bytes data;
        NFTStatus status;
    }
    mapping (uint256 => NFT) queue;
    uint256 public nQueue = 0;

    string public name;
    // Contract symbol
    string public symbol;

    modifier onlyWhitelistAdmin() {
        require(whitelistAdmins[msg.sender] == true, "WhitelistAdminRole: caller does not have the WhitelistAdmin role");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) public ERC1155(_uri) {
        name = _name;
        symbol = _symbol;
        whitelistAdmins[msg.sender] = true;
    }

    function setApproveable(bool _needApprove) external onlyOwner {
        needApprove = _needApprove;
    }

    function mint(address _owner, uint256 _maxSupply, string memory _uri, bytes memory _data) internal {
        currentTokenID = currentTokenID.add(1);
        _mint(msg.sender, currentTokenID, _maxSupply, _data);
        creators[currentTokenID] = _owner;
        tokenUri[currentTokenID] = _uri;
    }

    function create(
        uint256 _maxSupply,
        string memory _uri,
        bytes memory _data
    ) public {
        if (needApprove == true) {
            queue[nQueue] = NFT(msg.sender, _maxSupply, _uri, _data, NFTStatus.PENDING);
            ++nQueue;
        } else {
            mint(msg.sender, _maxSupply, _uri, _data);
        }
    }

    function approveNFT(uint256 _pendingId, uint256 _status)
    internal
    {
        NFT storage nft = queue[_pendingId];
        require(nft.status == NFTStatus.PENDING, 'not-pending-nft');
        nft.status = NFTStatus(_status);
        if (nft.status == NFTStatus.APPROVED) {
            mint(nft.owner, nft.maxSupply, nft.uri, nft.data);
        }
    }

    function batchApprove(uint256[] calldata _pendingIds, uint256[] calldata _status)
    external onlyWhitelistAdmin
    {
        for (uint256 i = 0; i < _pendingIds.length; i++) {
            approveNFT(_pendingIds[i], _status[i]);
        }
    }

    function uri(uint256 _tokenId)
    public override view returns (string memory _uri)
    {
        _uri = tokenUri[_tokenId];
    }
}

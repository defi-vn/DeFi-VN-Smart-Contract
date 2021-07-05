// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract PawnContract is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    mapping (address => uint256) whitelistCollateral;
    address public operator; 
    uint256 public penalty; // SYSTEM PENALTY
    mapping (address => uint256) systemFee; // SYSTEM FEE 
    uint256 public ZOOM;  
    bool public initialized = false;
    address coldWallet;
    address public admin;
    enum RepaymentCycleType {WEEK, MONTH}
    enum LoanDurationType {WEEK, MONTH}

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

    function setWhitelistCollateral(address _token, uint256 _status) external onlyOperator{
        whitelistCollateral[_token] = _status;
    }

    modifier notInitialized() {
        require(!initialized, "initialized");
        _;
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "caller is not the operator");
        _;
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "caller is not the admin");
        _;
    }

    function emergencyWithdraw(address _token)
    external onlyAdmin
    whenPaused {
        if (_token == address (0)) {
            payable(coldWallet).transfer(address(this).balance);
        } else {
            IERC20(_token).transfer(coldWallet, IERC20(_token).balanceOf(address(this)));
        }
    }

    /** ========================= COLLATERAL FUNCTIONS & STATES ============================= */
    uint256 public numberCollaterals;
    mapping (uint256 => Collateral) public collaterals;
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

    event CreateCollateralEvent(
        uint256 collateralId,
        Collateral data
    );

    event WithdrawCollateralEvent(
        uint256 collateralId,
        address collateralOwner
    );


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
            require(ERC20(_collateralAddress).balanceOf(address(this)) - preCollateralBalance == _amount, 'not-enough-collateral');
            ERC20(_collateralAddress).safeTransferFrom(msg.sender, address(this), _amount);
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

        emit CreateCollateralEvent(_idx, newCollateral);

        if (_packageId >= 0) {
            //package must active
            PawnShopPackage storage pawnShopPackage = pawnShopPackages[uint256(_packageId)];
            require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, 'package-not-support');

            _submitCollateralToPackage(_idx, uint256(_packageId));
            emit SubmitPawnShopPackage(uint256(_packageId), _idx, LoanRequestStatus.PENDING);
        }
    }

    /**
    * @dev cancel collateral function and return back collateral
    * @param  _collateralId is id of collateral
    */
    function withdrawCollateral(uint256 _collateralId) external {
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.owner == msg.sender, 'not-owner-of-this-collateral');
        require(collateral.status == CollateralStatus.OPEN, 'collateral-not-open');

        // Remove relation of collateral and offers
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        if (collateralOfferList.isInit == true) {
            for (uint i = 0; i < collateralOfferList.offerIdList.length; i ++) {
                uint256 offerId = collateralOfferList.offerIdList[i];
                Offer storage offer = collateralOfferList.offerMapping[offerId];
                emit CancelOfferEvent(offerId, _collateralId, offer.owner);
            }
            delete collateralOffersMapping[_collateralId];
        }

        if (collateral.collateralAddress != address(0)) {
            // transfer collateral to collateral's owner
            require(ERC20(collateral.collateralAddress).transfer(collateral.owner, collateral.amount), 'transfer-collateral-fail');     // Carefully check for security of this
        } else {
            payable(collateral.owner).transfer(collateral.amount);  // Carefully check for security of this
        }
        delete collaterals[_collateralId];
        emit WithdrawCollateralEvent(_collateralId, msg.sender);
    }

    /** ========================= OFFER FUNCTIONS & STATES ============================= */
    uint256 public numberOffers;
    enum OfferStatus {PENDING, ACCEPTED, COMPLETED, CANCEL}
    struct CollateralOfferList {
        mapping (uint256 => Offer) offerMapping;
        uint256[] offerIdList;
        bool isInit;
    }
    mapping (uint256 => CollateralOfferList) public collateralOffersMapping;
    struct Offer {
        address owner;
        address repaymentAsset;
        uint256 loanAmount;
        uint256 interest;
        uint256 duration;
        OfferStatus status;
        LoanDurationType loanDurationType;
        RepaymentCycleType repaymentCycleType;
        uint256 liquidityThreshold;
        bool isInit;
    }

    event CreateOfferEvent(
        uint256 offerId,
        uint256 collateralId,
        Offer data
    );

    event CancelOfferEvent(
        uint256 offerId,
        uint256 collateralId,
        address offerOwner
    );

    /**
    * @dev create Collateral function, collateral will be stored in this contract
    * @param _collateralId is id of collateral
    * @param _repaymentAsset is address of repayment token
    * @param _duration is duration of this offer
    * @param _loanDurationType is type for calculating loan duration
    * @param _repaymentCycleType is type for calculating repayment cycle
    * @param _liquidityThreshold is ratio of assets to be liquidated
    */

    function createOffer(
        uint256 _collateralId,
        address _repaymentAsset,
        uint256 _loanAmount,
        uint256 _duration,
        uint256 _interest,
        uint256 _loanDurationType,
        uint256 _repaymentCycleType,
        uint256 _liquidityThreshold
    )
    external whenNotPaused
    returns (uint256 _idx)
    {
        Collateral memory collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.OPEN, 'collateral-not-open');
        // validate not allow for collateral owner to create offer
        require(collateral.owner != msg.sender, 'collateral-owner-match-sender');
        // TODO: Validate logic of offer must match with collateral: loan amount, asset, ...

        Offer newOffer = _createOffer(
            _collateralId, 
            _repaymentAsset, 
            _loanAmount, 
            _duration, 
            _interest, 
            _loanDurationType, 
            _repaymentCycleType, 
            _liquidityThreshold
        );

        emit CreateOfferEvent(_idx, _collateralId, newOffer);
    }

    function _createOffer(
        uint256 _collateralId,
        address _repaymentAsset,
        uint256 _loanAmount,
        uint256 _duration,
        uint256 _interest,
        uint256 _loanDurationType,
        uint256 _repaymentCycleType,
        uint256 _liquidityThreshold
    ) internal returns (Offer _offer) {
        // Get offers of collateral
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        if (!collateralOfferList.isInit) {
            collateralOfferList.isInit = true;
        }
        // Create offer id       
        uint256 _idx = numberOffers;

        // Create offer data
        Offer storage newOffer = collateralOfferList.offerMapping[_idx];
        require (newOffer.isInit == false, 'internal-exception - _createOffer - newOffer.isInit');

        newOffer.isInit = true;
        newOffer.owner = msg.sender;
        newOffer.loanAmount = _loanAmount;
        newOffer.interest = _interest;
        newOffer.duration = _duration;
        newOffer.loanDurationType = LoanDurationType(_loanDurationType);
        newOffer.repaymentAsset = _repaymentAsset;
        newOffer.repaymentCycleType = RepaymentCycleType(_repaymentCycleType);
        newOffer.liquidityThreshold = _liquidityThreshold;
        newOffer.status = OfferStatus.PENDING;

        collateralOfferList.offerIdList.push(_idx);

        ++numberOffers;

        return newOffer;
    }

    /**
    * @dev cancel offer function, used for cancel offer
    * @param  _offerId is id of offer
    * @param _collateralId is id of collateral associated with offer
    */
    function cancelOffer(uint256 _offerId, uint256 _collateralId) 
    external {
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        require(collateralOfferList.isInit == true, 'collateral-not-have-any-offer');
        Offer storage offer = collateralOfferList.offerMapping[_offerId];
        require(offer.isInit == true, 'offer-not-sent-to-collateral');
        require(offer.owner == msg.sender, 'not-owner-of-offer');
        require(offer.status == OfferStatus.PENDING, 'offer-executed');
        _cancelOffer(collateralOfferList);
        emit CancelOfferEvent(_offerId, _collateralId, msg.sender);
    }

    function _cancelOffer(uint256 _offerId, CollateralOfferList _offerList) internal {
        delete _offerList.offerMapping[_offerId];
        for (uint i = 0; i < _offerList.offerIdList.length; i ++) {
            if (_offerList.offerIdList[i] == _offerId) {
                _offerList.offerIdList[i] = _offerList.offerIdList[_offerList.offerIdList.length - 1];
                break;
            }
        }

        delete _offerList[_offerList.offerIdList.length - 1];
    }

    /** ========================= PAWNSHOP PACKAGE FUNCTIONS & STATES ============================= */
    uint256 public numberPawnShopPackages;
    mapping (uint256 => PawnShopPackage) public pawnShopPackages;

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

    event CreatePawnShopPackage(
        uint256 packageId,
        PawnShopPackage data
    );

    event ChangeStatusPawnShopPackage(
        uint256 packageId,
        PawnShopPackageStatus status         
    );

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

        // Validataion logic: whitelist collateral, ranges must have upper greater than lower, duration type
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

    /** ========================= SUBMIT & ACCEPT WORKFLOW OF PAWNSHOP PACKAGE FUNCTIONS & STATES ============================= */
    enum LoanRequestStatus {PENDING, ACCEPTED, REJECTED, CONTRACTED, CANCEL}
    struct LoanRequestStatusStruct {
        bool isInit;
        LoanRequestStatus status;
    }
    struct CollateralAsLoanRequestListStruct {
        mapping (uint256 => LoanRequestStatusStruct) loanRequestToPawnShopPackageMapping; // Mapping from package to status
        uint256[] pawnShopPackageIdList;
        bool isInit;
    }
    mapping (uint256 => CollateralAsLoanRequestListStruct) collateralAsLoanRequestMapping; // Map from collateral to loan request
    event SubmitPawnShopPackage(
        uint256 packageId,
        uint256 collateralId,
        LoanRequestStatus status
    );

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

        // VALIDATE HAVEN'T SUBMIT TO PACKAGE YET
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        if (loanRequestListStruct.isInit == true) {
            LoanRequestStatusStruct storage statusStruct = loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];
            require(statusStruct.isInit == false, 'already-submit-to-package');
        }

        // Save
        _submitCollateralToPackage(_collateralId, _packageId);
        emit SubmitPawnShopPackage(_packageId, _collateralId, LoanRequestStatus.PENDING);
    }

    function _submitCollateralToPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) internal {
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        if (!loanRequestListStruct.isInit) {
            loanRequestListStruct.isInit = true;
        }
        LoanRequestStatusStruct storage statusStruct = loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];
        require(statusStruct.isInit == false, 'internal-exception:_submitCollateralToPackage - statusStruct.isInit');
        statusStruct.isInit = true;
        statusStruct.status = LoanRequestStatus.PENDING;
        loanRequestListStruct.pawnShopPackageIdList.push(_packageId);
    }

    function withdrawCollateralFromPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) external whenNotPaused {
        //TODO: VALIDATE
        _removeCollateralFromPackage(_collateralId, _packageId);
        emit SubmitPawnShopPackage(_packageId, _collateralId, LoanRequestStatus.CANCEL);
    }

    function _removeCollateralFromPackage (
        uint256 _collateralId,
        uint256 _packageId
    ) internal {
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        require(loanRequestListStruct.isInit == true, 'Internal Exception - loanRequestListStruct');
        require(loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId].isInit == true, 'Internal Exception - statusStruct');
        delete loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];

        for (uint i = 0; i < loanRequestListStruct.pawnShopPackageIdList.length - 1; i++){
            if (loanRequestListStruct.pawnShopPackageIdList[i] == _packageId) {
                loanRequestListStruct.pawnShopPackageIdList[i] = loanRequestListStruct.pawnShopPackageIdList[loanRequestListStruct.pawnShopPackageIdList.length - 1];
                break;
            }
        }
        delete loanRequestListStruct.pawnShopPackageIdList[loanRequestListStruct.pawnShopPackageIdList - 1];
    }

    function acceptCollateralOfPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) external whenNotPaused
    {
        // Check for owner of packageId
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.owner == msg.sender, 'not-owner-of-this-package');
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, 'package-not-inactive');        
        // Check for collateral status is open
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.OPEN, 'collateral-not-open');
        // Check for collateral-package status is PENDING (waiting for accept)
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        require(loanRequestListStruct.isInit == true, 'collateral-havent-had-any-loan-request');
        LoanRequestStatusStruct storage statusStruct = loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];
        require(statusStruct.isInit == true, 'collateral-havent-had-loan-request-for-this-package');
        require(statusStruct.status == LoanRequestStatus.PENDING, 'collateral-loan-request-for-this-package-not-PENDING');

        // Execute accept => change status of loan request to ACCEPTED, wait for system to generate contract
        _acceptCollateralOfPackage(_collateralId, _packageId);
        emit SubmitPawnShopPackage(_packageId, _collateralId, LoanRequestStatus.ACCEPTED);
    }

    function _acceptCollateralOfPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) internal {
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        require(loanRequestListStruct.isInit == true, 'Internal Exception - _acceptCollateralOfPackage - loanRequestListStruct.isInit');
        LoanRequestStatusStruct storage statusStruct = loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];
        require(statusStruct.isInit == true, 'Internal Exception - _acceptCollateralOfPackage - statusStruct.isInit');

        // Update status of loan request between _collateralId and _packageId to Accepted
        statusStruct.status = LoanRequestStatus.ACCEPTED;

        // Remove status of loan request between _collateralId and other packageId then emit event Cancel
        for (uint i = 0; i < loanRequestListStruct.pawnShopPackageIdList.length - 1; i++) {
            uint256 packageId = loanRequestListStruct.pawnShopPackageIdList[i];
            if (packageId != _packageId) {
                // Remove status
                delete loanRequestListStruct.loanRequestToPawnShopPackageMapping[packageId];
                emit SubmitPawnShopPackage(packageId, _collateralId, LoanRequestStatus.CANCEL);
            }
        }
        delete loanRequestListStruct.pawnShopPackageIdList;
        loanRequestListStruct.pawnShopPackageIdList.push(_packageId);

        // Remove relation of collateral and offers
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        if (collateralOfferList.isInit == true) {
            for (uint i = 0; i < collateralOfferList.offerIdList.length; i ++) {
                uint256 offerId = collateralOfferList.offerIdList[i];
                Offer storage offer = collateralOfferList.offerMapping[offerId];
                emit CancelOfferEvent(offerId, _collateralId, offer.owner);
            }
            delete collateralOffersMapping[_collateralId];
        }
    }

    function rejectCollateralOfPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) external whenNotPaused
    {
        // Check for owner of packageId
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.owner == msg.sender, 'not-owner-of-this-package');
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, 'package-not-inactive');        
        // Check for collateral status is open
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.OPEN, 'collateral-not-open');
        // Check for collateral-package status is PENDING (waiting for accept)
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        require(loanRequestListStruct.isInit == true, 'collateral-havent-had-any-loan-request');
        LoanRequestStatusStruct storage statusStruct = loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];
        require(statusStruct.isInit == true, 'collateral-havent-had-loan-request-for-this-package');
        require(statusStruct.status == LoanRequestStatus.PENDING, 'collateral-loan-request-for-this-package-not-PENDING');
        
        _removeCollateralFromPackage(_collateralId, _packageId);
        emit SubmitPawnShopPackage(_packageId, _collateralId, LoanRequestStatus.REJECTED);
    }

    /** ========================= CONTRACT RELATED FUNCTIONS & STATES ============================= */
    uint256 public numberContracts;    
    mapping (uint256 => Contract) public contracts;
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

    /** ================================ 1. ACCEPT OFFER (FOR P2P WORKFLOWS) ============================= */
    event AcceptOfferEvent(
        address fromAddress,
        uint256 contractId,
        uint256 collateralId,
        uint256 offerId,
        address offerOwner,
        address collateralOwner,
        uint256 startContract,
        uint256 endContract
    );

    /**
        * @dev accept offer and create contract between collateral and offer
        * @param  _collateralId is id of collateral
        * @param  _offerId is id of offer
        */
    function acceptOffer(uint256 _collateralId, uint256 _offerId) external whenNotPaused {
        Collateral storage collateral = collaterals[_collateralId];
        require(msg.sender == collateral.owner, 'not-collateral-owner');
        require(collateral.status == CollateralStatus.OPEN, 'collateral-not-open');

        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        require(collateralOfferList.isInit == true, 'collateral-not-have-any-offer');
        Offer storage offer = collateralOfferList.offerMapping[_offerId];
        require(offer.isInit == true, 'offer-not-sent-to-collateral');
        require(offer.status == OfferStatus.PENDING, 'offer-unavailable');

        //transfer loan asset to collateral owner
        ERC20(collateral.loanAsset).safeTransferFrom(offer.owner, collateral.owner, offer.loanAmount);
        //transfer systemFee to this contract
        ERC20(collateral.loanAsset).safeTransferFrom(offer.owner, address(this), systemFee[collateral.loanAsset]);

        // TODO: Revamp create contract
        uint256 contractId = createContract(_collateralId, _offerId);
        //change status of offer and collateral
        offer.status = OfferStatus.ACCEPTED;
        collateral.status = CollateralStatus.DOING;

        // Cancel other offer sent to this collateral
        for (uint256 i = 0; i < collateralOfferList.offerIdList.length; i++) {
            uint256 thisOfferId = collateralOfferList.offerIdList[i];
            if (thisOfferId != _offerId) {
                Offer storage thisOffer = collateralOfferList.offerMapping[thisOfferId];
                emit CancelOfferEvent(i, _collateralId, thisOffer.owner);

                delete collateralOfferList.offerMapping[thisOfferId];
            }
        }
        delete collateralOfferList.offerIdList;
        collateralOfferList.offerIdList.push(_offerId);

        emit AcceptOfferEvent(msg.sender, contractId, _collateralId, _offerId, offer.owner, collateral.owner, block.timestamp, block.timestamp + calculationOfferDuration(_offerId));
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

    /** ================================ 2. ACCEPT COLLATERAL (FOR PAWNSHOP PACKAGE WORKFLOWS) ============================= */
    /**
    * @dev create contract between package and collateral
    * @param  _collateralId is id of collateral
    * @param  _packageId is id of package
    * @param  _loanAmount is number of loan amout for lend
    * @param  _exchangeRate is exchange rate between collateral asset and loan asset, use for validate loan amount again loan to value configuration of package
    */
    function generateContractForCollateralAndPackage(
        uint256 _collateralId,
        uint256 _packageId,
        uint256 _loanAmount,
        uint256 _exchangeRate
    ) external whenNotPaused onlyOperator
    {
        // Package must active
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, 'package-not-inactive');        
        // Check for collateral status is DOING
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.DOING, 'collateral-not-open');
        // Check for collateral-package status is ACCEPTED (waiting for accept)
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        require(loanRequestListStruct.isInit == true, 'collateral-havent-had-any-loan-request');
        LoanRequestStatusStruct storage statusStruct = loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];
        require(statusStruct.isInit == true, 'collateral-havent-had-loan-request-for-this-package');
        require(statusStruct.status == LoanRequestStatus.ACCEPTED, 'collateral-loan-request-for-this-package-not-ACCEPTED');
        // TODO: loan amount calculate from _exchangeRate must same with loan to value of package

        // TODO: Create Contract

        // Change status of collateral loan request to package to CONTRACTED
        statusStruct.status == LoanRequestStatus.CONTRACTED;
        emit SubmitPawnShopPackage(_packageId, _collateralId, LoanRequestStatus.CONTRACTED);
    }

    /** ================================ 3. PAYMENT REQUEST & REPAYMENT WORKLOWS ============================= */
    /** ===================================== 3.1. PAYMENT REQUEST ============================= */
    mapping (uint256 => PaymentRequest[]) contractPaymentRequestMapping;
    enum PaymentRequestStatusEnum {ACTIVE, LATE, COMPLETE}
    enum PaymentRequestTypeEnum {MONTHLY, OVERDUE_MONTHLY}
    struct PaymentRequest {
        uint256 requestId;
        PaymentRequestTypeEnum paymentRequestType;
        uint256 remainingLoan;
        uint256 penalty;
        uint256 interest;
        uint256 remainingPenalty;
        uint256 remainingInterest;
        uint256 dueDateTimestamp;
        PaymentRequestStatusEnum status;
    }
    event PaymentRequestEvent (
        uint256 contractId,
        PaymentRequest data
    );

    /**
        End lend period settlement and generate invoice for next period
     */
    function closePaymentRequestAndStartNew(
        uint256 _contractId,
        uint256 _remainingLoan,
        uint256 _nextPhrasePenalty,
        uint256 _nextPhraseInterest,
        uint256 _dueDateTimestamp,
        PaymentRequestTypeEnum _paymentRequestType

    ) external whenNotPaused onlyOperator {
        // TODO: Validate
        // - Validate time must over due date
        // - Contract valid
        // - Operator valid
        // - remaining loan, valid

        // Check if number of requests is 0 => create new requests, if not then update current request as LATE or COMPLETE and create new requests
        PaymentRequest[] storage requests = contractPaymentRequestMapping[_contractId];
        if (requests.length > 0) {
            // not first phrase, update previous
            // check for remaining penalty and interest, if greater than zero then is Lated, otherwise is completed
            PaymentRequest storage previousRequest = requests[requests.length - 1];
            if (previousRequest.remainingInterest > 0 || previousRequest.remainingPenalty > 0) {
                previousRequest.status = PaymentRequestStatusEnum.LATE;
            } else {
                previousRequest.status = PaymentRequestStatusEnum.COMPLETE;
            }
        }

        // Create new payment request and store to contract
        PaymentRequest memory newRequest = PaymentRequest({
            requestId: requests.length,
            paymentRequestType: _paymentRequestType,
            remainingLoan: _remainingLoan,
            penalty: _nextPhrasePenalty,
            interest: _nextPhraseInterest,
            remainingPenalty: 0,
            remainingInterest: 0,
            dueDateTimestamp: _dueDateTimestamp,
            status: PaymentRequestStatusEnum.ACTIVE
        });
        requests.push(newRequest);

        emit PaymentRequestEvent(_contractId, newRequest);
    }

    /** ===================================== 3.2. REPAYMENT ============================= */
    


    /** ================ OLD VERSION ======== */
    uint256 public numberPaymentHistory;
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

    mapping (uint256 => PaymentHistory) public paymentHistories;
    mapping (uint256 => mapping(uint256 => RepaymentPhase)) public repaymentPhases; // REMOVE
    mapping (address => mapping(uint256 => uint256)) public lastOffer;  // ???

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

    /**
    * @dev repayment for pawn contract
    * @param  _contractId is id contract
    */
    function repayment(
        uint256 _contractId,
        uint256 _payForInterest,
        uint256 _payForPenalty,
        uint256 _payForLoan
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
        if (_payForPenalty > repaymentPhase.remainingFines) {
            _payForPenalty = repaymentPhase.remainingFines;
        }
        repaymentPhase.remainingInterest -= _payForInterest;
        repaymentPhase.remainingLoan -= _payForLoan;
        repaymentPhase.remainingFines -= _payForPenalty;
        repaymentPhase.paidForInterest += _payForInterest;
        repaymentPhase.paidForLoan += _payForLoan;
        repaymentPhase.paidForFines += _payForPenalty;

        ERC20(offer.repaymentAsset).safeTransferFrom(msg.sender, offer.owner, _payForInterest);
        ERC20(offer.repaymentAsset).safeTransferFrom(msg.sender, offer.owner, _payForLoan);
        ERC20(offer.repaymentAsset).safeTransferFrom(msg.sender, offer.owner, _payForPenalty);

        //the borrower has paid off all the debt
        if (repaymentPhase.remainingInterest + repaymentPhase.remainingLoan+ repaymentPhase.remainingFines== 0) {
            executeLiquidity(_contractId);
        }
        uint256 historyId = createPaymentHistory(_contractId, msg.sender, offer.repaymentAsset, _payForLoan, _payForInterest, _payForPenalty);
        emit Repayment(historyId, _contractId, _contract.currentRepaymentPhase, offer.repaymentAsset, _payForLoan, _payForInterest, _payForPenalty);
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

}

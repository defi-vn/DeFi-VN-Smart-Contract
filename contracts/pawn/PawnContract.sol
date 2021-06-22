// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


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
    enum CollateralSubmitPawnShopPackageStatus {PENDING, ACCEPTED, REJECTED, CONTRACTED, CANCEL}

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

    enum CollateralProposalType {LOAN_PACKAGE, OFFER}
    struct CollateralProposal {
        CollateralProposalType proposalType; // is Loan package or Offer
        uint32 dataId;  // is id of loan package or offer
        uint8 status;   // status of loan package if proposal is package
    }

    mapping (uint256 => Offer) public offers;
    mapping (uint256 => Collateral) public collaterals;
    mapping (uint256 => PawnShopPackage) public pawnShopPackages;
    mapping (uint256 => Contract) public contracts;
    mapping (uint256 => PaymentHistory) public paymentHistories;
    mapping (uint256 => mapping(uint256 => CollateralSubmitPawnShopPackageStatus)) public pawnShopPackageSubmittedCollaterals;
    mapping (uint256 => CollateralProposal[]) public collateralProposals;

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
        uint256 collateralId,
        CollateralSubmitPawnShopPackageStatus status
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

            CollateralProposal storage collateralProposal = collateralProposals[_idx];
            collateralProposal.proposalType = CollateralProposalType.LOAN_PACKAGE;
            collateralProposal.dataId = _packageId;
            collateralProposal.status = CollateralSubmitPawnShopPackageStatus.PENDING;

            emit SubmitPawnShopPackage(uint256(_packageId), _idx, CollateralSubmitPawnShopPackageStatus.PENDING);
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
    
        CollateralProposal storage collateralProposal = collateralProposals[_collateralId];
        collateralProposal.proposalType = CollateralProposalType.LOAN_PACKAGE;
        collateralProposal.dataId = _packageId;
        collateralProposal.status = CollateralSubmitPawnShopPackageStatus.PENDING;


        pawnShopPackageSubmittedCollaterals[_packageId][_collateralId] = CollateralSubmitPawnShopPackageStatus.PENDING;
        collateralSubmittedToPawnShop[_collateralId][_packageId] = CollateralSubmitPawnShopPackageStatus.PENDING;

        emit SubmitPawnShopPackage(_packageId, _collateralId, CollateralSubmitPawnShopPackageStatus.PENDING);
    }

    function acceptCollateralOfPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) external whenNotPaused
    {
        // Check package
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        // check for owner of packageId
        require(pawnShopPackage.owner == msg.sender, 'not-owner-of-this-package');
        // check for status of package must be active
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, 'package-not-active');

        // Check collateral
        // check for status of collateral must be OPEN
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.OPEN, 'collateral-not-open');

        // Check for status of collateral-package must be PENDING
        require(pawnShopPackageSubmittedCollaterals[_packageId][_collateralId] == CollateralSubmitPawnShopPackageStatus.PENDING, 'invalid-status-collateral-link-package');
        require(collateralSubmittedToPawnShop[_collateralId][_packageId] == CollateralSubmitPawnShopPackageStatus.PENDING, 'invalid-status-collateral-link-package');

        // Process update state
        // Set status of this collateral-package to ACCEPTED
        pawnShopPackageSubmittedCollaterals[_packageId][_collateralId] = CollateralSubmitPawnShopPackageStatus.ACCEPTED;
        collateralSubmittedToPawnShop[_collateralId][_packageId] = CollateralSubmitPawnShopPackageStatus.ACCEPTED;
        // set status of collateral to accepted
        collateral.status = CollateralStatus.DOING;
        // set status of other offer link to this collateral to cancel
        for (uint256 i = 0; i < numberOffers; i++) {
            if (offers[i].collateralId == _collateralId) {
                offers[i].status = OfferStatus.CANCEL;
                emit CancelOffer(i, offers[i].owner);
            }
        }
        // set status of other collateral-package-link to cancel
        

        emit SubmitPawnShopPackage(_packageId, _collateralId, CollateralSubmitPawnShopPackageStatus.ACCEPTED);
    }

    function rejectCollateralOfPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) external whenNotPaused
    {
        // TODO: Store status of package id and collateral id for: waiting for accept, accepted, rejected
        // TODO: check for owner of packageId
        // TODO: check for collateral-package status is waiting for accept
        // TODO: change status of collateral-package to rejected
        pawnShopPackageSubmittedCollaterals[_packageId][_collateralId] = CollateralSubmitPawnShopPackageStatus.REJECTED;
        collateralSubmittedToPawnShop[_collateralId][_packageId] = CollateralSubmitPawnShopPackageStatus.REJECTED;
        emit SubmitPawnShopPackage(_packageId, _collateralId, CollateralSubmitPawnShopPackageStatus.REJECTED);
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

//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

//This wallet contains a modular consensus-based mechanism. Owners of the wallet can modify the minimum signatures needed to deploy a contract.

contract MultiSigWallet {

    address private _owner;
    mapping(address => uint) private _owners;
    address public contractAd;

    uint public MIN_SIGNATURES = 2;
    uint private _transactionIdx;
    uint private _contractsIdx;
    uint private _consensusIdx;
    

    struct Contracts {
      bytes contractBytecode;
      bool proposed;
      uint signatureCount;
      mapping (address => uint) signatures;
    }

    struct Transaction {
      address from;
      address payable to;
      uint amount;
      uint signatureCount;
      mapping (address => uint) signatures;
    }
    
    struct Consensus {
        uint minSig;
        bool proposed;
        uint signatureCount;
        mapping(address => uint) signatures;
    }

    mapping (uint => Contracts) private _contracts;
    mapping (uint => Transaction) private _transactions;
    mapping (uint => Consensus) private _consensus;
    uint[] private _pendingTransactions;
    uint[] private _pendingContracts;
    uint[] private _pendingConsensus;

    modifier isOwner() {
        require(msg.sender == _owner);
        _;
    }

    modifier validOwner() {
        require(msg.sender == _owner || _owners[msg.sender] == 1);
        _;
    }

    event DepositFunds(address from, uint amount);
    event TransactionCreated(address from, address to, uint amount, uint transactionId);
    event TransactionCompleted(address from, address to, uint amount, uint transactionId);
    event TransactionSigned(address by, uint transactionId);
    event Received(address, uint);
    event ContractDeployed(address indexed contractAddress, bytes returnedData);
    event ContractCreated(address createdBy, bytes bytecode,uint ContractIndex);
    event ContractSigned(address signedBy, uint contractId);
    event ContractCompleted(bytes bytecode, uint contractId);
    event ConsensusCreated(address createdBy, uint minSig, uint consensusId);
    event ConsensusSigned(address signedBy, uint consensusId);
    event ConsensusApproved(uint minSig, uint consensusId);

    constructor (){
        _owner = msg.sender;
    }

    function addOwner(address owner)
        validOwner
        public {
        _owners[owner] = 1;
    }

    function removeOwner(address owner)
        validOwner
        public {
        _owners[owner] = 0;
    }

    fallback()
        external
        payable {
        emit DepositFunds(msg.sender, msg.value);
    }
    
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    
    function transferTo(address payable to, uint amount)
        validOwner
        public {
        require(address(this).balance >= amount);
        uint transactionId = _transactionIdx++;

        Transaction storage transaction = _transactions[transactionId];
        transaction.from = msg.sender;
        transaction.to = to;
        transaction.amount = amount;
        transaction.signatureCount = 0;

        _pendingTransactions.push(transactionId);

        emit TransactionCreated(msg.sender, to, amount, transactionId);
    }
    
    function walletBalance()
      public
      view
      returns (uint) {
      return address(this).balance;
    }
    
    //consensus Mechanism
    function proposeConsensusMech(uint _minSig)validOwner public{
        uint consensusId = _consensusIdx++;

        Consensus storage consensus = _consensus[consensusId];
        consensus.minSig = _minSig;
        consensus.signatureCount = 0; 
        consensus.proposed = true;
        _pendingConsensus.push(consensusId);
        emit ConsensusCreated(msg.sender, _minSig, consensusId);
    }
    
    function signConsensusMech(uint consensusId)validOwner public{
       Consensus storage consensus = _consensus[consensusId];
      // contract must exist
      require(consensus.proposed == true);
      require(consensus.signatures[msg.sender] != 1);

      consensus.signatures[msg.sender] = 1;
      consensus.signatureCount++;

      emit ConsensusSigned(msg.sender, consensusId);

      if (consensus.signatureCount >= MIN_SIGNATURES) {
        MIN_SIGNATURES = consensus.minSig;
        deleteConsensus(consensusId);
        emit ConsensusApproved(MIN_SIGNATURES, consensusId);
      }
    }

    //transaction functions

    function getPendingTransactions()
      view
      validOwner
      public
      returns (uint[] memory) {
      return _pendingTransactions;
    }

    function signTransaction(uint transactionId)
      validOwner
      public {

      Transaction storage transaction = _transactions[transactionId];

      // Transaction must exist
      require(address(0) != transaction.from);
      // Cannot sign a transaction more than once
      require(transaction.signatures[msg.sender] != 1);

      transaction.signatures[msg.sender] = 1;
      transaction.signatureCount++;

      emit TransactionSigned(msg.sender, transactionId);

      if (transaction.signatureCount >= MIN_SIGNATURES) {
        require(address(this).balance >= transaction.amount);
        transaction.to.transfer(transaction.amount);
        emit TransactionCompleted(transaction.from, transaction.to, transaction.amount, transactionId);
        deleteTransaction(transactionId);
      }
    }
    
    //contract creation functions
    
    function proposeSmartContract(bytes memory _byteCode)validOwner public{
        uint contractId = _contractsIdx++;

        Contracts storage con = _contracts[contractId];
        con.contractBytecode = _byteCode;
        con.signatureCount = 0; 
        con.proposed = true;
        _pendingContracts.push(contractId);
        emit ContractCreated(msg.sender, _byteCode, contractId);
    }
    
    function signSmartContract(uint contractId)validOwner public payable returns(address){
       Contracts storage con = _contracts[contractId];
       address _contractAddress = address(0);
       bytes memory _returnedData;
      // contract must exist
      require(con.proposed == true);
      require(con.signatures[msg.sender] != 1);

      con.signatures[msg.sender] = 1;
      con.signatureCount++;

      emit ContractSigned(msg.sender, contractId);

      if (con.signatureCount >= MIN_SIGNATURES) {
        (_contractAddress,_returnedData) = createSmartContract(con.contractBytecode);
        emit ContractCompleted(con.contractBytecode, contractId);
        deleteContract(contractId);
        contractAd = _contractAddress;
        return _contractAddress;
      }
      contractAd = _contractAddress;
      return _contractAddress;
    }
    
   function createSmartContract (bytes memory _byteCode)
    internal returns (
      address _contractAddress, bytes memory _returnedData) {
    
    assembly {
      _contractAddress := create (
          callvalue (), add (_byteCode, 0x20), mload (_byteCode))
      let l := returndatasize ()
      let p := mload (0x40)
      _returnedData := p
      mstore (p, l)
      p := add (p, 0x20)
      returndatacopy (p, 0x0, l)
      mstore (0x40, add (p, l))
    }

    emit ContractDeployed (_contractAddress, _returnedData);
  }
  
  //internal functions

    function deleteTransaction(uint transactionId)
      validOwner
      internal {
      uint replace = 0;
      for(uint i = 0; i < _pendingTransactions.length; i++) {
        if (1 == replace) {
          _pendingTransactions[i-1] = _pendingTransactions[i];
        } else if (transactionId == _pendingTransactions[i]) {
          replace = 1;
        }
      }
      if(replace==1){
        _pendingTransactions.pop();
        delete _transactions[transactionId];
      }
      
    }
    
    function deleteContract(uint contractId)
      validOwner
      internal {
      uint replace = 0;
      for(uint i = 0; i < _pendingContracts.length; i++) {
        if (1 == replace) {
          _pendingContracts[i-1] = _pendingContracts[i];
        } else if (contractId == _pendingContracts[i]) {
          replace = 1;
        }
      }
      if(replace==1){
        _pendingContracts.pop();
        delete _contracts[contractId];
      }
      
    }
    
    function deleteConsensus(uint consensusId)
      validOwner
      internal {
      uint replace = 0;
      for(uint i = 0; i < _pendingConsensus.length; i++) {
        if (1 == replace) {
          _pendingConsensus[i-1] = _pendingConsensus[i];
        } else if (consensusId == _pendingConsensus[i]) {
          replace = 1;
        }
      }
      if(replace==1){
        _pendingConsensus.pop();
        delete _consensus[consensusId];
      }
      
    }
}

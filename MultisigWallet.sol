//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

contract MultiSigWallet {

    address private _owner;
    mapping(address => uint8) private _owners;

    uint constant MIN_SIGNATURES = 2;
    uint private _transactionIdx;
    uint private _contractsIdx;

    struct Contracts {
      bytes contractBytecode;
      bool proposed;
      uint8 signatureCount;
      mapping (address => uint8) signatures;
    }

    struct Transaction {
      address from;
      address payable to;
      uint amount;
      uint8 signatureCount;
      mapping (address => uint8) signatures;
    }

    mapping (uint => Contracts) private _contracts;
    mapping (uint => Transaction) private _transactions;
    uint[] private _pendingTransactions;
    uint[] private _pendingContracts;

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
    event ContractCreated(address by, bytes bytecode,uint ContractIndex);
    event ContractSigned(address signedBy, uint contractId);
    event ContractCompleted(bytes bytecode, uint contractId);

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

    // function withdraw(uint amount)
    //     public {
    //     transferTo(msg.sender, amount);
    // }

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
    //   // Creator cannot sign the transaction
    //   require(msg.sender != transaction.from);
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
    
    function proposeSmartContract(bytes memory _byteCode)validOwner public{
        uint contractId = _contractsIdx++;

        Contracts storage con = _contracts[contractId];
        con.contractBytecode = _byteCode;
        con.signatureCount = 0; 
        con.proposed = true;
        _pendingContracts.push(contractId);
        emit ContractCreated(msg.sender, _byteCode, contractId);
    }
    
    function signSmartContract(uint contractId)validOwner public payable{
       Contracts storage con = _contracts[contractId];

      // contract must exist
      require(con.proposed == true);
      require(con.signatures[msg.sender] != 1);

      con.signatures[msg.sender] = 1;
      con.signatureCount++;

      emit ContractSigned(msg.sender, contractId);

      if (con.signatureCount >= MIN_SIGNATURES) {
        createSmartContract(con.contractBytecode);
        emit ContractCompleted(con.contractBytecode, contractId);
        deleteContract(contractId);
      }
    }
    
   function createSmartContract (bytes memory _byteCode)
    internal returns (
      address _contractAddress, bytes memory _returnedData) {
    // Contract creation may be performed only by the contract itself
    //require (msg.sender == address (this));

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

    function deleteTransaction(uint transactionId)
      validOwner
      public {
      uint8 replace = 0;
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
      public {
      uint8 replace = 0;
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

    function walletBalance()
      public
      view
      returns (uint) {
      return address(this).balance;
    }
}

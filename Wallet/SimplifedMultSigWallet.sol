//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

//This wallet is only used to deploy a contract, it does not have the regular features of a MultiSig wallet (transaction tracking, balance checking, money transferring etc.)
//It was developed to reduce deployment cost

contract MultiSigWallet {

    address private _owner;
    mapping(address => uint) private _owners;
    address public contractAd;

    uint constant MIN_SIGNATURES = 2;
    uint private _contractsIdx;

    struct Contracts {
      bytes contractBytecode;
      bool proposed;
      uint signatureCount;
      mapping (address => uint) signatures;
    }
    
    mapping (uint => Contracts) private _contracts;
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
    // Contract creation may be performed only by the contract itself
    //require (msg.sender == address (this), "someone other than MultiSigWallet is trying to create contract");

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
}

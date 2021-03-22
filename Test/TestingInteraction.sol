// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

//we use this contract to interact with the deployed 1_Storage contract from TestingMultisigWallet
//only for testing purposes.
contract test{
    address dc; //address of deployed contract
    
    function setAddressOfDeployedContract(address _t) public {
        dc = _t;
    }

     event setsig(bool contractAddress, bytes returnedData);
     event getsig(bool contractAddress, bytes returnedData);
  
    function setStorage(uint _val) public returns(bool _success, bytes memory){
        bytes memory payload = abi.encodeWithSignature("store(uint256)", _val);
        (bool success, bytes memory returnData) = address(dc).call(payload);
        emit setsig (success, returnData);
        return (success, returnData);
    }
    
    function getStorage() public returns(bool _success, bytes memory){
        bytes memory payload = abi.encodeWithSignature("retrieve()");
        (bool success, bytes memory returnData) = address(dc).call(payload);
        emit getsig (success, returnData);
        return (success, returnData);
    }

}

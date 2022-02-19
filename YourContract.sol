pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";

import "./BokkyPooBahsDateTimeLibrary.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// import "@openzeppelin/contracts/access/Ownable.sol"; 
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol




contract YourContract 
{
   string public _lastMessage;

   address private owner = 0x942B539aff9D599a7d79f4AE541F7eAe69e0E03f; 

   struct Loan 
   {
      uint length;
      uint payment;
      uint[] dueDates;
      uint[] payments;
      uint numPaymentsMade;
      bool hasLoan;
   }

   mapping(address => Loan) private loans;
   mapping(address => int) private creditScores;


   modifier hasContract() 
   {
      require(loans[msg.sender].hasLoan == true, "You do not have a loan on this contract!");
      _;
   }


   modifier notPaidUp()
   {
      require(loans[msg.sender].numPaymentsMade != loans[msg.sender].length, "Your loan has been paid in full.");
      _;
   }

   
   constructor()
   {
   }


   function fundContract() public payable
   {
      require(msg.sender == owner, "You must own the contract to fund it.");
   }
   


   function commitToLoan(uint length, uint payment) public
   {
      require(loans[msg.sender].hasLoan == false, "You already have a loan on this contract!");
      require(length == 3 || length == 6 || length == 12 || length == 24);
      
      Loan memory aLoan;
      aLoan.length = length;
      aLoan.payment = payment;
      aLoan.hasLoan = true;

      uint rightNow = block.timestamp;
      aLoan.dueDates = new uint256[](length);
      aLoan.payments = new uint256[](length);

      for (uint i = 0; i < length; ++i) 
      {
         aLoan.dueDates[i] = BokkyPooBahsDateTimeLibrary.addMonths(rightNow, i + 1);
      }
      loans[msg.sender] = aLoan;
   }



   function commitToLoanWithInitialLatePayment(uint length, uint payment) public
   {
      require(loans[msg.sender].hasLoan == false, "You already have a loan on this contract!");
      require(length == 3 || length == 6 || length == 12 || length == 24);
      
      Loan memory aLoan;
      aLoan.length = length;
      aLoan.payment = payment;
      aLoan.hasLoan = true;

      uint rightNow = block.timestamp;
      aLoan.dueDates = new uint256[](length);
      aLoan.payments = new uint256[](length);

      uint firstPaymentDate = BokkyPooBahsDateTimeLibrary.subDays(rightNow, 5);
      firstPaymentDate = BokkyPooBahsDateTimeLibrary.subMonths(firstPaymentDate, 1);

      for (uint i = 0; i < length; ++i) 
      {
         aLoan.dueDates[i] = BokkyPooBahsDateTimeLibrary.addMonths(firstPaymentDate, i + 1);
      }
      loans[msg.sender] = aLoan;
   }


   function cancelLoan() public hasContract notPaidUp()
   {
      if (loans[msg.sender].numPaymentsMade > 0)
      {
         uint principalPaid = loans[msg.sender].numPaymentsMade * loans[msg.sender].payment;
         uint penalty = principalPaid / 100;

         (bool success, ) = msg.sender.call{value: principalPaid - penalty}("");
               
         _lastMessage = string(abi.encodePacked(
            "We paid you back the principal you paid minus a 1% cancellation fee for a total of ", 
            Strings.toString(principalPaid - penalty), 
            " wei."));
         require(success, "FAILED");
      }

      creditScores[msg.sender] += _scoreCurrentContract(msg.sender) -7;
      loans[msg.sender].hasLoan = false;
   }



   function makePayment() public hasContract notPaidUp payable
   {
      require(msg.value == loans[msg.sender].payment, 
         string(abi.encodePacked("Your payment must be ",
         Strings.toString(loans[msg.sender].payment),
         " wei.")));

      uint paymentNum = loans[msg.sender].numPaymentsMade;
      loans[msg.sender].payments[paymentNum] = block.timestamp;
      loans[msg.sender].numPaymentsMade += 1;

      if (loans[msg.sender].numPaymentsMade == loans[msg.sender].length)
      {
         creditScores[msg.sender] += _scoreCurrentContract(msg.sender) + 10;
         loans[msg.sender].hasLoan = false;
         uint principal = loans[msg.sender].length * loans[msg.sender].payment;
         uint interest = (10 * principal) / 100;
         (bool success, ) = msg.sender.call{value: principal + interest}("");
               
         _lastMessage = string(abi.encodePacked(
            "Congratulations! You paid off your loan. We paid you back ", 
            Strings.toString(principal + interest), 
            " wei."));
         require(success, "FAILED");
      }
   }


   function myLoanTerms() public hasContract returns(Loan memory)
   {
      Loan memory aLoan = loans[msg.sender];
      
      _lastMessage = string(abi.encodePacked(
         "Your contract is ", 
         Strings.toString(aLoan.length), 
         " months long with payments of ", 
         Strings.toString(aLoan.payment), 
         " wei."));
      
      return aLoan;
   }


   function getNextPaymentDate() public hasContract notPaidUp returns(uint)
   {
      Loan memory aLoan = loans[msg.sender];
      uint dueDate = aLoan.dueDates[aLoan.numPaymentsMade];
      (uint year, uint month, uint day) = BokkyPooBahsDateTimeLibrary.timestampToDate(dueDate);

      _lastMessage = string(abi.encodePacked(
         "Your next payment is due on ",
         Strings.toString(month), "/",
         Strings.toString(day), "/",
         Strings.toString(year)));

      return dueDate;
   }


   function getPaymentDate(uint paymentNum) public hasContract returns(uint)
   {
      require(paymentNum >= 1 && paymentNum <= loans[msg.sender].dueDates.length, "Invalid payment number");
      uint dueDate = loans[msg.sender].dueDates[paymentNum - 1];
      (uint year, uint month, uint day) = BokkyPooBahsDateTimeLibrary.timestampToDate(dueDate);

      _lastMessage = string(abi.encodePacked(
         "Payment #",
         Strings.toString(paymentNum),
         " is due on ",
         Strings.toString(month), "/",
         Strings.toString(day), "/",
         Strings.toString(year)));

      return dueDate;
   }


   function getCreditScore() public returns(int)
   {
      return _getCreditScore(msg.sender);      
   }

   function getCreditScore(address borrower) public returns(int)
   {
      return _getCreditScore(borrower);
   } 


   function _getCreditScore(address borrower) private returns(int)
   {
      int scoreForCurrentContract = _scoreCurrentContract(borrower);
      int retValue = scoreForCurrentContract + creditScores[borrower];
      if (retValue >= 0)
      {
         _lastMessage = string(abi.encodePacked(
            "Your credit score on this contract is ",
            Strings.toString((uint)(retValue))));
      }
      else
      {
         _lastMessage = string(abi.encodePacked(
            "Your credit score on this contract is -",
            Strings.toString((uint)(retValue * -1))));
      }

      return retValue;
   }


   function _scoreCurrentContract(address borrower) private view returns(int)
   {
      int scoreForCurrentContract = 0;
      if (loans[borrower].hasLoan)
      {
         Loan memory aLoan = loans[borrower];
         // First score payments made
         for (uint i = 0; i < aLoan.numPaymentsMade; ++i)
         {
            if (aLoan.payments[i] <= aLoan.dueDates[i])
            {
               scoreForCurrentContract += 5;
            }
            else
            {
               scoreForCurrentContract -= 3;
            }
         }
         
         // Now score if any payments due, but not yet made
         for (uint i = aLoan.numPaymentsMade; i < aLoan.length; ++i)
         {
            uint rightNow = block.timestamp;
            if (rightNow > aLoan.dueDates[i])
            {
               scoreForCurrentContract -= 5;
            }
         }
      }
      return scoreForCurrentContract;
   }
}

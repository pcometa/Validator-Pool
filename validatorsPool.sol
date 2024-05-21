    // SPDX-License-Identifier: MIT
    pragma solidity 0.8.20;

    import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
    import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
    import "./land.sol";
    import "./sales.sol";
    import "./headSeason.sol";
    import "./candidate.sol";
    contract ValidatorsPool is ReentrancyGuard {
        //................events....................
        event validatorVoteEvent(address _validator,uint256 _vote,string _trackId);
        event validatorWithdrawEvent(address _validator,uint256 _amount,string _trackId);
        event investorWithdrawEvent(address _investor,uint256 _amount,string _trackId);
        event createValidatorsEvent(createValidatorsInformations[] _validatorsInfo,string _trackId);
        event calculateVotesEvent(string _trackId);
        event pauseWithdrawEvent(string _trackId);
        event unPauseWithdrawEvent(string _trackId);
        //.............varaibles..............//
        uint256 public totalAmountEntered=0;
        uint256 public totalStocks;
        uint256 public startVotingTime;
        uint256 public endVotingTime;
        uint8 public validatorsVotingId=0;
        address owner;
        uint256 public currentTax;
        IERC20 public token;
        validatorVotingInfo[] public validatorsVoting;
        taxVotesNumber[] public taxCounts;
        LandContract public landContract;
        Sales public salesContract;
        HeadSeason public headSeasonContract;
        address public stakeContract;
        Candidate public candidateContract;
        ExmodulesMarketPlace public nftMarketPlaceContract;
        NFTSales public nftSalesContract;
        bool isVotesCounted=false;
        uint256 public taxVoteLimitation=50;
        bool public pause=true;
        //...........................enums.......................//
        enum accessibleFunctions{
            createValidators,
            calculateVotes,
            updateTaxVoteLimitation,
            addLiquidity
        }
        //..............................structs............................//
        struct validatorDetails{
            uint256 stockAmount;
            uint256 totalAmountWithdrawn;
            withdrawDetails[] withdrawHistory;
            uint8 validatorVotingId;
            uint8 investorsProfitPercentage;
        }

        struct withdrawDetails{
            uint256 amount;
            uint256 withdrawTime;
        }

        struct createValidatorsInformations{
            address validatorAddress;
            uint256 stockAmount;
            uint8 investorsProfitPercentage;
        }

        struct validatorVotingInfo{
            address validatorAddress;
            uint256 vote;
            bool isAlreadyVoted;
        }

        struct taxVotesNumber{
            uint256 tax;
            uint256 votesNumber;
        }

        struct investorWithdrawDetails{
            uint256 withdrawnAmount;
            withdrawDetails[] withdrawHistory;
        }
        //...................maps..........................//
        mapping (address =>validatorDetails)public validators;
        mapping (address =>mapping (address =>investorWithdrawDetails))public investorWithdraw;
        mapping(address=>mapping (uint8 => bool))public operators;
        //..........................modifiers.............................//
        modifier onlyOwner() {
            require(msg.sender == owner, "You are not the owner of the contract");
            _;
        }

        modifier onlyLandContract(){
            if(msg.sender==address(landContract) || msg.sender==address(salesContract)
             || msg.sender==address(nftMarketPlaceContract) || msg.sender==address(nftSalesContract) || msg.sender==owner
             ){
                _;
            }
            else{
                revert("this function can only called by land or sales contract");
            }
        }

        modifier onlyStakeContract(){
            require(msg.sender==stakeContract,"this function can only called by stake contract");
            _;
        }

        modifier onlyOwnerAndOperators(uint8 _accessibleFunctionsId){
            if(msg.sender==owner || operators[msg.sender][_accessibleFunctionsId]){
                _;
            }
            else{
                revert("You are not the owner of the contract or you don't have access to call this function");
            }
        }

        constructor(
            address _token,
            address _landContractAddress,address _salesContractAddress,
            uint256 _currentTax,uint256 _startVotingTime,uint256 _endVotingTime,address _owner,
            address _candidateCotractAddress,address _headSeasonContractAddress,
            address _stakeContractAddress
            ,address _nftMarketPlaceContractAddress,address _nftSalesContractAddress
            ){
            landContract=LandContract(_landContractAddress);
            salesContract=Sales(_salesContractAddress);
            token=IERC20(_token);
            owner=_owner;
            currentTax=_currentTax;
            startVotingTime=_startVotingTime;
            endVotingTime=_endVotingTime;
            candidateContract=Candidate(_candidateCotractAddress);
            headSeasonContract=HeadSeason(_headSeasonContractAddress);
            stakeContract=_stakeContractAddress;
            nftMarketPlaceContract=ExmodulesMarketPlace(_nftMarketPlaceContractAddress);
            nftSalesContract=NFTSales(_nftSalesContractAddress);
        }

        //...........................functions.................................
        function createValidators(createValidatorsInformations[] memory _validatorsInfo,string memory _trackId) public onlyOwnerAndOperators(0){
            for (uint256 i=0; i<_validatorsInfo.length; i++)
            {
                if(validators[_validatorsInfo[i].validatorAddress].stockAmount==0){
                    validators[_validatorsInfo[i].validatorAddress].stockAmount=_validatorsInfo[i].stockAmount;
                    validators[_validatorsInfo[i].validatorAddress].totalAmountWithdrawn=0;
                    validators[_validatorsInfo[i].validatorAddress].investorsProfitPercentage=_validatorsInfo[i].investorsProfitPercentage;
                    validators[_validatorsInfo[i].validatorAddress].validatorVotingId=validatorsVotingId;
                    totalStocks+=_validatorsInfo[i].stockAmount;
                    validatorsVoting.push(validatorVotingInfo(_validatorsInfo[i].validatorAddress,currentTax,false));
                    validatorsVotingId++;
                }
            }
            emit createValidatorsEvent(_validatorsInfo,_trackId);
        }

        function addLiquidity(uint256 _amount)public onlyLandContract(){
            totalAmountEntered= totalAmountEntered+_amount;
        }

        function withdrawAmountForValidator(uint256 _amount,string memory _trackId)public nonReentrant(){
            require(pause==false,"You can't call this function at this moment");
            require(validators[msg.sender].stockAmount!=0,"You are not the validator for this contract");
            uint256 valuePerStock=totalAmountEntered/totalStocks;
            uint256 totalAmount=valuePerStock * validators[msg.sender].stockAmount;
            uint256 investorsProfitTokenAmount=(totalAmount * validators[msg.sender].investorsProfitPercentage)/100;
            uint256 withdrawableAmount=totalAmount-(validators[msg.sender].totalAmountWithdrawn+investorsProfitTokenAmount);
            require(withdrawableAmount>=_amount,"You don't have this amount to withdraw");
            if(token.balanceOf(address(this))>=_amount){
                validators[msg.sender].totalAmountWithdrawn=validators[msg.sender].totalAmountWithdrawn+_amount;
                validators[msg.sender].withdrawHistory.push(withdrawDetails(_amount,block.timestamp));
                require(token.transfer(msg.sender, _amount),"Transaction failed");
                emit validatorWithdrawEvent(msg.sender,_amount,_trackId);
            }
            else{
                revert("The balance of the contract is not enough");
            }
        }

        function addvalidatorVote(uint256 _vote,string memory _trackId)public {
            require(validators[msg.sender].stockAmount!=0,"You are not the validator for this contract");
            if(startVotingTime>block.timestamp || endVotingTime<block.timestamp){
                revert("Voting has not yet started or ended");
            }
            require(validatorsVoting[validators[msg.sender].validatorVotingId].isAlreadyVoted==false,"You have already voted");
            if(_vote<currentTax-taxVoteLimitation || _vote>currentTax+taxVoteLimitation){
                revert("You can only vote 5 above or below the current tax");
            }
            validatorsVoting[validators[msg.sender].validatorVotingId].vote=_vote;
            validatorsVoting[validators[msg.sender].validatorVotingId].isAlreadyVoted=true;
            emit validatorVoteEvent(msg.sender,_vote,_trackId);
        }

        function calculateVotes(string memory _trackId) public onlyOwnerAndOperators(1) {
            require(block.timestamp > endVotingTime, "Voting is not over yet");
            require(isVotesCounted==false,"Votes have already counted");
            for (uint256 i = 0; i < validatorsVoting.length; i++) {
                bool voteAlreadyCounted = false;

                for (uint256 j = 0; j < taxCounts.length; j++) {
                    if (taxCounts[j].tax == validatorsVoting[i].vote) {
                        taxCounts[j].votesNumber++;
                        voteAlreadyCounted = true;
                        break;
                    }
                }


                if (!voteAlreadyCounted) {
                    taxCounts.push(taxVotesNumber(validatorsVoting[i].vote, 1));
                }
            }

            uint256 populartaxVote = 0;
            uint256 maxVote = 0;
            uint256 secondPopulartaxVote=0;
            uint256 secondMaxVote=0;
            for (uint256 k = 0; k < taxCounts.length; k++) {
                if (taxCounts[k].votesNumber >= maxVote) {
                    secondMaxVote=maxVote;
                    secondPopulartaxVote=populartaxVote;
                    maxVote = taxCounts[k].votesNumber;
                    populartaxVote = taxCounts[k].tax;
                }
            }

            if(maxVote==secondMaxVote){
                isVotesCounted=true;
                salesContract.updateTax(currentTax);
                landContract.updateTax(currentTax);
                headSeasonContract.updateTax(currentTax);
                if(address(nftMarketPlaceContract) !=address(0) && address(nftSalesContract) !=address(0)){
                    nftMarketPlaceContract.updateTax(currentTax);
                    nftSalesContract.updateTax(currentTax);
                }
            }
            else{
                isVotesCounted=true;
                salesContract.updateTax(populartaxVote);
                landContract.updateTax(populartaxVote);
                headSeasonContract.updateTax(populartaxVote);
                if(address(nftMarketPlaceContract) !=address(0) && address(nftSalesContract) !=address(0)){
                    nftMarketPlaceContract.updateTax(populartaxVote);
                    nftSalesContract.updateTax(populartaxVote);
                }
            }
            emit calculateVotesEvent(_trackId);
        }

        function withdrawInvestorProfit(address _investorAddress,uint256 _amount,address _validatorAddress,string memory _trackId)public onlyStakeContract(){
            require(pause==false,"You can't call this function at this moment");
            require(validators[_validatorAddress].stockAmount!=0,"Validator is not found");
            uint256 InvestorinvestmentAmount;
            uint256 InvestorvalidatorTotalInvestedAmount;
            (InvestorinvestmentAmount,InvestorvalidatorTotalInvestedAmount)=candidateContract.getInvestorDetails(_investorAddress, _validatorAddress);
            require(InvestorinvestmentAmount!=0,"You have not invested yet on this validator");
            uint256 validatorTotalInvestmentAmount=InvestorvalidatorTotalInvestedAmount;
            uint256 totalInvestmentPercentage= (InvestorinvestmentAmount * 100)/validatorTotalInvestmentAmount;
            uint256 valuePerStock=totalAmountEntered/totalStocks;
            uint256 totalvalidatorProfitAmount=valuePerStock * validators[_validatorAddress].stockAmount;
            uint256 investorsProfitTokenAmount=(totalvalidatorProfitAmount * validators[_validatorAddress].investorsProfitPercentage)/100;
            uint256 currentInvestorProfitAmount=(investorsProfitTokenAmount * totalInvestmentPercentage)/100;
            uint256 withdrawableAmount=currentInvestorProfitAmount-investorWithdraw[_investorAddress][_validatorAddress].withdrawnAmount;
            require(withdrawableAmount>=_amount,"You do not have this amount of interest to withdraw");
            if(token.balanceOf(address(this))>=_amount){
                investorWithdraw[_investorAddress][_validatorAddress].withdrawnAmount+=_amount;
                investorWithdraw[_investorAddress][_validatorAddress].withdrawHistory.push(withdrawDetails(_amount,block.timestamp));
                require(token.transfer(_investorAddress, _amount),"Transaction failed");
                emit investorWithdrawEvent(_investorAddress,_amount,_trackId);
            }
            else{
                revert("The balance of the contract is not enough");
            }
        }

        
        function calculateValidatorProfit()public view returns(uint256,uint256){
            require(validators[msg.sender].stockAmount!=0,"You are not the validator for this contract");
            uint256 valuePerStock=totalAmountEntered/totalStocks;
            uint256 totalAmount=valuePerStock * validators[msg.sender].stockAmount;
            uint256 investorsProfitTokenAmount=(totalAmount * validators[msg.sender].investorsProfitPercentage)/100;
            uint256 withdrawableAmount=totalAmount-(validators[msg.sender].totalAmountWithdrawn+investorsProfitTokenAmount);

            return (totalAmount-(investorsProfitTokenAmount),withdrawableAmount);
        }

        function calculateInvestorProfit(address _validatorAddress)public view returns(uint256,uint256){
            require(validators[_validatorAddress].stockAmount!=0,"Validator is not found");
            uint256 InvestorinvestmentAmount;
            uint256 InvestorvalidatorTotalInvestedAmount;
            (InvestorinvestmentAmount,InvestorvalidatorTotalInvestedAmount)=candidateContract.getInvestorDetails(msg.sender, _validatorAddress);
            require(InvestorinvestmentAmount!=0,"You have not invested yet on this validator");
            uint256 validatorTotalInvestmentAmount=InvestorvalidatorTotalInvestedAmount;
            uint256 totalInvestmentPercentage= (InvestorinvestmentAmount * 100)/validatorTotalInvestmentAmount;
            uint256 valuePerStock=totalAmountEntered/totalStocks;
            uint256 totalvalidatorProfitAmount=valuePerStock * validators[_validatorAddress].stockAmount;
            uint256 investorsProfitTokenAmount=(totalvalidatorProfitAmount * validators[_validatorAddress].investorsProfitPercentage)/100;
            uint256 currentInvestorProfitAmount=(investorsProfitTokenAmount * totalInvestmentPercentage)/100;
            uint256 withdrawableAmount=currentInvestorProfitAmount-investorWithdraw[msg.sender][_validatorAddress].withdrawnAmount;
            
            return (currentInvestorProfitAmount,withdrawableAmount);
        }

        function addOperator(address _operator,uint8 _accessibleFunctionsId)public onlyOwner(){
            require(!operators[_operator][_accessibleFunctionsId],"operator is already added");
            operators[_operator][_accessibleFunctionsId]=true;
        }

        function removeOperator(address _operator,uint8 _accessibleFunctionsId)public onlyOwner(){
            require(operators[_operator][_accessibleFunctionsId],"operator not found");
            delete operators[_operator][_accessibleFunctionsId];
        }

        function updateTaxVoteLimitation(uint256 _newTaxVoteLimitation)public onlyOwnerAndOperators(2){
            taxVoteLimitation=_newTaxVoteLimitation;
        }

        function setNFTMarketContracts(address _nftMarketContractAddress,address _salesNFTContractAddress)public{
            nftMarketPlaceContract=ExmodulesMarketPlace(_nftMarketContractAddress);
            nftSalesContract=NFTSales(_salesNFTContractAddress);
        }

        function unPauseWithdraw(string memory _trackId)public onlyOwner(){
            pause=false;
            emit unPauseWithdrawEvent(_trackId);
        }

        function pauseWithdraw(string memory _trackId)public onlyOwner(){
            pause=true;
            emit pauseWithdrawEvent(_trackId);
        }

        function updateStakeContract(address _stakeContractAddress)public onlyOwner(){
            stakeContract=_stakeContractAddress;
        }

        function updateLandAndSales(address _land,address _sales)public onlyOwner(){
            landContract=LandContract(_land);
            salesContract=Sales(_sales);
        }

        function addNftMarketContracts(address _nftMarketContractAddress,address _salesNFTContractAddress)public onlyOwner(){
            nftMarketPlaceContract=ExmodulesMarketPlace(_nftMarketContractAddress);
            nftSalesContract=NFTSales(_salesNFTContractAddress);
        }
    }

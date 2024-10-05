module botsocean_payments::payment {
    use std::error;
    use std::signer;
    use std::string;
    use aptos_framework::coin::{Coin, transfer};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event;
    #[test_only]
    use std::debug;
    
    #[event]
    /// Withdrawal request structure
    struct WithdrawalRequest has drop, store {
        user: address,
        amount: u64,
    }

    /// Holds information about the deposit and withdrawal events
    #[event]
    struct Deposit has drop, store {
        user: address,
        amount: u64,
    }

    #[event]
    struct ExecutedWithdrawal has drop, store {
        user: address,
        amount: u64,
    }

    /// Holds the global state for the contract, including the masternode address and event handles
    //:!:>resource
    struct PaymentState has key {
        masternode: address,
        total_withdrawals: u64,
        deposit_event: EventHandle<DepositEvent>,
        withdrawal_event: EventHandle<WithdrawalEvent>,
    }
    //<:!:resource

    /// Store pending withdrawal requests from users
    struct PendingWithdrawals has key {
        withdrawals: vector<Withdrawal>,
    }

    /// Initialize the contract and set the masternode account
    public entry fun initialize(account: &signer, masternode_addr: address) {
        let state = PaymentState {
            masternode: masternode_addr,
            total_withdrawals: 0,
            deposit_event: Event::new<DepositEvent>(account),
            withdrawal_event: Event::new<WithdrawalEvent>(account),
        };
        move_to(account, state);
    }

    /// Function for users to deposit APT tokens into their account
    public entry fun deposit(account: &signer, amount: u64) {
        let user_addr = signer::address_of(account);

        // Transfer APT coins to the contract
        let coins = aptos_framework::coin::withdraw<AptosCoin>(account, amount);
        aptos_framework::coin::deposit<AptosCoin>(user_addr, coins);

        // Emit event for deposit
        let state = borrow_global_mut<PaymentState>(user_addr);
        Event::emit_event<DepositEvent>(&mut state.deposit_event, DepositEvent { user: user_addr, amount });
    }

    /// Function for users/providers to request withdrawal
    public entry fun request_withdrawal(account: &signer, amount: u64) {
      let user_addr = signer::address_of(account);

      // Record the withdrawal request
      if (!exists<PendingWithdrawals>(user_addr)) {
        move_to(account, PendingWithdrawals { withdrawals: vector::empty<Withdrawal>() });
      };

      let pending_withdrawals = borrow_global_mut<PendingWithdrawals>(user_addr);
      let new_request = Withdrawal { user: user_addr, amount };
      vector::push_back(&mut pending_withdrawals.withdrawals, new_request);

      // Emit event for withdrawal request
      let state = borrow_global_mut<PaymentState>(user_addr);
      Event::emit_event<WithdrawalEvent>(&mut state.withdrawal_event, WithdrawalEvent { user: user_addr, amount });
    }

    /// Function for the masternode to process and send withdrawals
    public entry fun execute_withdrawal(account: &signer, withdrawals: vector<Withdrawal>) {
        let masternode_addr = signer::address_of(account);
        let state = borrow_global<PaymentState>(masternode_addr);

        // Ensure only the masternode can execute withdrawals
        assert!(masternode_addr == state.masternode, 1);

        // Process withdrawals
        let len = vector::length<Withdrawal>(&withdrawals);
        let i = 0;
        while (i < len) {
            let withdrawal = vector::borrow<Withdrawal>(&withdrawals, i);
            let user_addr = withdrawal.user;
            let amount = withdrawal.amount;

            // Transfer coins to the user
            let coins = aptos_framework::coin::withdraw<AptosCoin>(account, amount);
            aptos_framework::coin::deposit<AptosCoin>(user_addr, coins);

            i = i + 1;
        }
    }
}
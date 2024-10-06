module botsocean::payment {
    use std::signer;
    use std::vector;
    use aptos_framework::coin::{transfer};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event;
    #[test_only]
    use std::debug;

    #[event]
    struct WithdrawalRequest has drop, store {
        user: address
    }

    #[event]
    struct Deposit has drop, store {
        user: address,
        amount: u64
    }

    #[event]
    struct ExecutedWithdrawal has drop, store {
        user: address,
        amount: u64
    }

    struct PaymentState has key {
        epoch: u64,
        pendingWithdrawals: vector<address>
    }

    struct WithdrawalOrder {
        user: address,
        amount: u64
    }

    const NOT_OWNER: u64 = 0;
    const UNINITIALIZED: u64 = 1;
    const ALREADY_INIT: u64 = 2;
    const BADREQ_EXECWITHDRAW: u64 = 3;

    /// Authority init PaymentState under its address
    public entry fun initialize(signer: &signer) {
        assert!(signer::address_of(signer) == @botsocean, NOT_OWNER);
        assert!(!exists<PaymentState>(@botsocean), ALREADY_INIT);
        let state = PaymentState {
            epoch: 0,
            pendingWithdrawals: vector::empty<address>()
        };
        move_to(signer, state);
    }

    /// Function for users to deposit APT tokens into their account
    public entry fun deposit(account: &signer, amount: u64) {
        assert!(exists<PaymentState>(@botsocean), UNINITIALIZED);
        let user_addr = signer::address_of(account);
        transfer<AptosCoin>(account, @botsocean, amount);

        event::emit(Deposit { user: user_addr, amount });
    }

    /// Function for users/providers to request withdrawal
    public entry fun request_withdrawal(account: &signer) acquires PaymentState {
        assert!(exists<PaymentState>(@botsocean), UNINITIALIZED);
        let payment_state = borrow_global_mut<PaymentState>(@botsocean);
        let user_addr = signer::address_of(account);
        let pending_withdrawals = &mut payment_state.pendingWithdrawals;
        vector::push_back(pending_withdrawals, user_addr);

        event::emit(WithdrawalRequest { user: user_addr });
    }

    /// Function for the masternode to process and send withdrawals
    public entry fun execute_withdrawal(
        signer: &signer,
        withdrawal_addrs: vector<address>,
        withdrawal_amts: vector<u64>
    ) acquires PaymentState {
        assert!(signer::address_of(signer) == @botsocean, NOT_OWNER);
        assert!(exists<PaymentState>(@botsocean), UNINITIALIZED);
        assert!(
            vector::length(&withdrawal_addrs) == vector::length(&withdrawal_amts),
            BADREQ_EXECWITHDRAW
        );

        // Process withdrawals
        let len = vector::length(&withdrawal_addrs);
        let i = 0;
        while (i < len) {
            let user_addr = vector::borrow(&withdrawal_addrs, i);
            let amount = vector::borrow(&withdrawal_amts, i);
            transfer<AptosCoin>(signer, *user_addr, *amount);
            event::emit(ExecutedWithdrawal { user: *user_addr, amount: *amount });
            i = i + 1;
        };

        let payment_state = borrow_global_mut<PaymentState>(@botsocean);
        payment_state.epoch = payment_state.epoch + 1;
        payment_state.pendingWithdrawals = vector::empty();
    }
}

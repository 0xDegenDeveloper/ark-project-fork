use arkchain::order::order_v1::OrderV1;
use arkchain::order::types::RouteType;
use snforge_std::{
    declare, ContractClassTrait, spy_events, EventSpy, EventFetcher, EventAssertions, Event, SpyOn,
    test_address
};
use arkchain::orderbook::{OrderbookDispatcher, OrderbookDispatcherTrait};

const ORDER_VERSION_V1: felt252 = 'v1';

#[test]
fn test_cancel_offer() {
    let contract = declare('orderbook');
    let mut params = ArrayTrait::new();
    params.append(0x0);

    let contract_address = contract.deploy(@params).unwrap();
    let dispatcher = OrderbookDispatcher { contract_address };
// dispatcher.create_order();

// let order_hash = '123';

// dispatcher
//     .create_order(
//         0, arkchain::orderbook::SignInfo { user_pubkey: 0, user_sig_r: 0, user_sig_s: 0 }
//     );

// dispatcher
//     .cancel_order(
//         0, arkchain::orderbook::SignInfo { user_pubkey: 0, user_sig_r: 0, user_sig_s: 0 }
//     );
}

fn get_offer_order() -> OrderV1 {
    let data = array![];
    let data_span = data.span();
    OrderV1 {
        route: RouteType::Erc20ToErc721.into(),
        currency_address: 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
            .try_into()
            .unwrap(),
        currency_chain_id: 0x534e5f4d41494e.try_into().unwrap(),
        salt: 0,
        offerer: 0x00E4769a4d2F7F69C70951A003eBA5c32707Cef3CdfB6B27cA63567f51cdd078
            .try_into()
            .unwrap(),
        token_chain_id: 0x534e5f4d41494e.try_into().unwrap(),
        token_address: 0x01435498bf393da86b4733b9264a86b58a42b31f8d8b8ba309593e5c17847672
            .try_into()
            .unwrap(),
        token_id: 0,
        quantity: 1,
        start_amount: 600000000000000000,
        end_amount: 0,
        start_date: 1699525884797,
        end_date: 1702117884797,
        broker_id: 123,
        additional_data: data_span,
    }
}

use arkchain::order::types::OrderTrait;
use core::result::ResultTrait;
use core::traits::Into;
use core::traits::TryInto;
use arkchain::order::order_v1::OrderV1;
use arkchain::order::order_v1::OrderTraitOrderV1;
use arkchain::order::types::OrderType;
use snforge_std::PrintTrait;
use arkchain::order::types::RouteType;
use super::super::super::setup::order;

// *********************************************************
// validate_common_data
// *********************************************************

#[test]
fn test_validate_common_data_with_valid_order() {
    let (order_listing, _, _, _) = setup();
    let block_timestamp: u64 = 1699556828; // 09/11/2023 20:07:08
    let result = order_listing.validate_common_data(block_timestamp);
    assert(result.is_ok(), 'Invalid result');
}

#[test]
fn should_returns_invalid_order_with_zero_quantity() {
    let (order_listing, _, _, _) = setup();
    let block_timestamp: u64 = 1699556828;

    let mut invalid_order = order_listing.clone();
    invalid_order.quantity = 0;
    let result = invalid_order.validate_common_data(block_timestamp);
    assert(!result.is_ok(), 'zero quantity');
}

#[test]
fn should_returns_invalid_order_with_zero_salt() {
    let (order_listing, _, _, _) = setup();
    let block_timestamp: u64 = 1699556828;

    let mut invalid_order = order_listing.clone();
    invalid_order.salt = 0;
    let result = invalid_order.validate_common_data(block_timestamp);
    assert(!result.is_ok(), 'zero salt');
}

#[test]
fn should_returns_invalid_order_with_invalid_token_address() {
    let (order_listing, _, _, _) = setup();
    let block_timestamp: u64 = 1699556828;

    let mut invalid_order = order_listing.clone();
    invalid_order.token_address = 0.try_into().unwrap();
    let result = invalid_order.validate_common_data(block_timestamp);
    assert(!result.is_ok(), 'invalid token address');
}

#[test]
fn should_returns_invalid_order_with_invalid_dates() {
    let (order_listing, _, _, _) = setup();
    let block_timestamp: u64 = 1699556828; // 09/11/2023 20:07:08

    let mut invalid_order = order_listing.clone();
    invalid_order.end_date = 0;
    let result = invalid_order.validate_common_data(block_timestamp);
    assert(!result.is_ok(), 'zero end date');

    let mut invalid_order = order_listing.clone();
    invalid_order.end_date = invalid_order.start_date;
    let result = invalid_order.validate_common_data(block_timestamp);
    assert(!result.is_ok(), 'start date = end date');

    let mut invalid_order = order_listing.clone();
    invalid_order.start_date = block_timestamp - 1;
    let result = invalid_order.validate_common_data(block_timestamp);
    assert(result.is_err(), 'result must be invalid');
    assert(
        result.unwrap_err() == arkchain::order::types::OrderValidationError::StartDateInThePast,
        'start date in the past'
    );

    let mut invalid_order = order_listing.clone();
    invalid_order.start_date = block_timestamp - (10 * 24 * 60 * 60); // - 10 days
    invalid_order.end_date = block_timestamp + (31 * 24 * 60 * 60); // + 31 days
    let result = invalid_order.validate_common_data(block_timestamp);
    assert(result.is_err(), 'result must be invalid');
    assert(
        result.unwrap_err() == arkchain::order::types::OrderValidationError::StartDateInThePast,
        'start date in the past'
    );

    let mut invalid_order = order_listing.clone();
    invalid_order.start_date = block_timestamp + (1 * 24 * 60 * 60); // + 1 day
    invalid_order.end_date = block_timestamp + (31 * 24 * 60 * 60); // + 31 days
    let result = invalid_order.validate_common_data(block_timestamp);
    assert(result.is_err(), 'result must be invalid');
    assert(
        result.unwrap_err() == arkchain::order::types::OrderValidationError::EndDateTooFar,
        'end date too far'
    );
}

#[test]
fn test_validate_order_listing() {
    let (order_listing, _, _, _) = setup();
    let validated_order = order_listing.validate_order_type();
    // test for order type detection validity
    assert(validated_order.is_ok(), 'Fail to validate order type');
    assert(validated_order.unwrap() == OrderType::Listing, 'Fail for type listing');
}

#[test]
fn test_validate_order_offer() {
    let (_, order_offer, _, _) = setup();
    let validated_order = order_offer.validate_order_type();
    // test for order type detection validity
    assert(validated_order.is_ok(), 'Fail to validate order type');
    assert(validated_order.unwrap() == OrderType::Offer, 'Fail for type offer');
}

#[test]
fn test_validate_order_auction() {
    let (_, _, order_auction, _) = setup();
    let validated_order = order_auction.validate_order_type();
    // test for order type detection validity
    assert(validated_order.is_ok(), 'Fail to validate order type');
    assert(validated_order.unwrap() == OrderType::Auction, 'Fail for type auction');
}

#[test]
fn test_validate_order_collection_offer() {
    let (_, _, _, order_collection_offer) = setup();

    let mut invalid_offer = order_collection_offer.clone();
    invalid_offer.token_id = Option::Some(123);
    let invalid_order = invalid_offer.validate_order_type();
    assert(invalid_order.unwrap() != OrderType::CollectionOffer, 'Fail for type collection offer');

    let validated_order = order_collection_offer.validate_order_type();
    // test for order type detection validity
    assert(validated_order.is_ok(), 'Fail to validate order type');
    assert(
        validated_order.unwrap() == OrderType::CollectionOffer, 'Fail for type collection offer'
    );
}

fn setup() -> (OrderV1, OrderV1, OrderV1, OrderV1,) {
    let data = array![];
    let data_span = data.span();

    let order_listing = OrderV1 {
        route: RouteType::Erc721ToErc20.into(),
        currency_address: 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
            .try_into()
            .unwrap(),
        currency_chain_id: 0x534e5f4d41494e.try_into().unwrap(),
        salt: 1,
        offerer: 0x00E4769a4d2F7F69C70951A003eBA5c32707Cef3CdfB6B27cA63567f51cdd078
            .try_into()
            .unwrap(),
        token_chain_id: 0x534e5f4d41494e.try_into().unwrap(),
        token_address: 0x01435498bf393da86b4733b9264a86b58a42b31f8d8b8ba309593e5c17847672
            .try_into()
            .unwrap(),
        token_id: Option::Some(10),
        quantity: 1,
        start_amount: 600000000000000000,
        end_amount: 0,
        start_date: 1699643228,
        end_date: 1700420828,
        broker_id: 123,
        additional_data: data_span,
    };
    let order_offer = OrderV1 {
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
        token_id: Option::Some(23),
        quantity: 1,
        start_amount: 600000000000000000,
        end_amount: 0,
        start_date: 1699525884797,
        end_date: 1702117884797,
        broker_id: 123,
        additional_data: data_span,
    };
    let order_auction = OrderV1 {
        route: RouteType::Erc721ToErc20.into(),
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
        token_id: Option::Some(10),
        quantity: 1,
        start_amount: 600000000000000000,
        end_amount: 600000000000000000,
        start_date: 1696874828,
        end_date: 1699556828,
        broker_id: 123,
        additional_data: data_span,
    };

    let order_collection_offer = OrderV1 {
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
        token_id: Option::None,
        quantity: 1,
        start_amount: 600000000000000000,
        end_amount: 0,
        start_date: 1699525884797,
        end_date: 1702117884797,
        broker_id: 123,
        additional_data: data_span,
    };

    (order_listing, order_offer, order_auction, order_collection_offer)
}

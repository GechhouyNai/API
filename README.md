# Coffee E-commerce Backend API

A starter REST API built with **Dart Frog + MongoDB**. It contains backend code only; there is no React, HTML, or CSS frontend.

## Included endpoints

| Method   | Endpoint                      | Purpose                                                            |
| -------- | ----------------------------- | ------------------------------------------------------------------ |
| GET      | `/`                           | API welcome and health-check link                                  |
| GET      | `/api/`                        | API welcome and endpoint links                                     |
| GET      | `/api/health`                 | Check API and MongoDB                                              |
| POST     | `/api/auth/signup`            | Create an account                                                  |
| POST     | `/api/auth/register`          | Alias for signup                                                   |
| POST     | `/auth/register`               | Alias for signup when `baseUrl` does not include `/api`            |
| POST     | `/api/auth/login`             | Log in and receive a JWT                                           |
| GET      | `/api/auth/me`                | Read the logged-in user's profile                                  |
| POST     | `/api/auth/logout`            | Log out (discard the stateless JWT on the client)                  |
| POST     | `/api/auth/forgot_password`  | Generate a password-reset code (development response is opt-in)    |
| POST     | `/api/auth/reset_password`   | Reset a password using a valid, unexpired code                     |
| GET      | `/api/coffees`                | List the menu; supports `?type=HOT`, `?type=ICED`, `?search=latte` |
| POST     | `/api/coffees`                | Create a coffee                                                    |
| GET      | `/api/coffees/:id`            | Get one coffee                                                     |
| PATCH    | `/api/coffees/:id`            | Update a coffee                                                    |
| DELETE   | `/api/coffees/:id`            | Delete a coffee                                                    |
| GET      | `/api/menu`                  | Legacy menu listing; searches both current and legacy coffee data  |
| GET      | `/api/menu/:id`              | Get one coffee from either menu collection                         |
| GET      | `/api/stores`                | List active stores                                                 |
| GET      | `/api/favorites`              | List the user's favorites                                          |
| POST     | `/api/favorites`              | Add a favorite (`coffeeId`)                                        |
| DELETE   | `/api/favorites/:id`          | Remove a favorite                                                  |
| GET      | `/api/cart`                   | Get the user's cart                                                |
| POST     | `/api/cart`                   | Add an item (`coffeeId`, `quantity`)                               |
| PATCH    | `/api/cart/:id`               | Change quantity                                                    |
| DELETE   | `/api/cart/:id`               | Remove an item                                                     |
| GET      | `/api/orders`                 | List the user's orders                                             |
| POST     | `/api/orders`                 | Create an order from the cart                                      |
| GET      | `/api/orders/:id`             | Get one of the user's orders                                       |
| POST     | `/api/payments/khqr`          | Create a Bakong KHQR payment for an order                          |
| POST     | `/api/payments/bakong/create` | Alias for creating a Bakong KHQR payment                           |
| POST     | `/api/payments/bakong/verify` | Verify a payment using its KHQR MD5 hash                           |
| GET/POST | `/api/payments/bakong/token`  | Admin-only Bakong token status/save/renew                          |
| GET      | `/api/payments/:id`           | Get one of the logged-in user's payments                           |
| POST     | `/api/payments/:id/check`     | Verify one of the logged-in user's payments                        |

## 1. Requirements

- Dart SDK 3.3 or later
- Dart Frog CLI
- MongoDB running locally, or a MongoDB Atlas connection string
- Postman (for testing)

Install the Dart Frog CLI:

```bash
dart pub global activate dart_frog_cli
```

## 2. Setup

The Dart Frog application is the `coffee_backend_api` project root: the directory containing `pubspec.yaml`, `lib/`, and `routes/`. Run all commands below from that directory. Do not run the API from the nested `backend/` scaffold; it does not contain the auth or coffee routes.

```bash
if [ ! -f .env ]; then cp .env.example .env; fi
dart pub get
dart_frog dev
```

Edit `MONGO_URI` and `JWT_SECRET` in `.env`. Do not commit `.env` to Git.
Password-reset codes are not returned by default. For local testing only, set
`RESET_CODE_IN_RESPONSE=true` to include `devResetCode` in the forgot-password
response; connect a delivery provider before using this flow in production.

## 3. Start local MongoDB (macOS)

If MongoDB is installed locally:

```bash
mkdir -p ~/data/db
mongod --dbpath ~/data/db
```

Keep that terminal open. In another terminal, start the API with `dart_frog dev`.

For MongoDB Atlas, use the connection string from Atlas in `.env` instead of the local URI. Make sure your Atlas Network Access rules allow your current IP.

## 4. Postman examples

Base URL: `http://localhost:8080`

### Health

`GET http://localhost:8080/api/health`

### API root

`GET http://localhost:8080/`

### Sign up

`POST http://localhost:8080/api/auth/signup`
Body → raw → JSON:

```json
{
  "name": "Test User",
  "phone": "012345678",
  "email": "test@example.com",
  "password": "StrongPassword123"
}
```

### Login

`POST http://localhost:8080/api/auth/login`

```json
{
  "email": "test@example.com",
  "password": "StrongPassword123"
}
```

Copy the returned `token`. For protected routes, add:
`Authorization: Bearer YOUR_TOKEN`

### Create a coffee

`POST http://localhost:8080/api/coffees`
Header: `Authorization: Bearer YOUR_TOKEN`

```json
{
  "title": "Vanilla Latte",
  "desc": "Espresso with steamed milk and vanilla.",
  "image": "https://example.com/vanilla-latte.jpg",
  "price": 3.5,
  "type": "HOT",
  "isAvailable": true
}
```

### Filter coffee

`GET http://localhost:8080/api/coffees?type=ICED`

### Add to cart

`POST http://localhost:8080/api/cart`

```json
{
  "coffeeId": "PASTE_COFFEE_ID",
  "quantity": 2
}
```

### Place order

`POST http://localhost:8080/api/orders`

```json
{
  "deliveryAddress": "Phnom Penh"
}
```

## 5. Important notes

- This is a learning starter, not a production-ready deployment.
- The sample protects user-specific routes with JWT authentication. Coffee create/update/delete currently require a valid logged-in user; add a proper admin role check before production.
- Never store plaintext passwords. Signup hashes passwords with bcrypt.
- Never expose your MongoDB URI, JWT secret, or Bakong token.
- Bakong KHQR is generated server-side with the pure-Dart `khqr_generator` package. Orders are converted from USD to KHR using `BAKONG_KHR_PER_USD` (default example: 4100).
- Payment verification calls Bakong Open API `check_transaction_by_md5`. The API checks the receiving merchant account, KHR amount, currency, and duplicate transaction hash before marking the payment and order as paid.
- The Bakong Open API token is stored in MongoDB collection `api_bakong`. Protect token management with the `x-admin-api-key` header; the GET endpoint never returns the token itself.
- You must obtain the real ABA-registered Bakong Account ID, Merchant ID, and SIT/testing Open API token. The sample values are placeholders. Do not use `coffee@bakong` unless ABA has confirmed it is your real registered merchant account.
- Set `BAKONG_API_URL=https://sit-api-bakong.nbc.gov.kh` for SIT/testing. Do not use production credentials with the SIT endpoint or vice versa.
- A QR being created or a payment remaining `PENDING` does not mean it has been paid. Only a successful server-side Bakong verification updates the order to `CONFIRMED`.
- Validate and sanitize all input, add rate limits, HTTPS, logging, tests, and role-based authorization before production.

## 6. Bakong KHQR setup and testing

1. Copy `.env.example` to `.env` and set `MONGO_URI`, `JWT_SECRET`, and a strong `ADMIN_API_KEY`.
2. Ask ABA for your real merchant Bakong Account ID, Merchant ID, and SIT/testing Open API token. Put them in the matching `BAKONG_*` settings. Never paste secrets into chat or commit `.env`.
3. Install dependencies and start the API:

```bash
dart pub get
dart_frog dev
```

4. Import `postman/Bakong-Payments.postman_collection.json` into Postman. Set `adminApiKey`, `token` (the user JWT), `orderId`, and Bakong token/email variables.
5. Run requests 1-3 to check/save/renew the Bakong token. Requests 1-3 require `x-admin-api-key`; do not send this key from a public frontend.
6. Log in to the Coffee API, create an order from the cart, and copy the order ID into `orderId`. Run request 4 to generate the KHQR. Scan the QR with a Bakong-compatible wallet, then run request 5 to verify. Requests 6-7 can retrieve/check a payment by ID.

### Postman request details

- Create KHQR: `POST /api/payments/bakong/create` with `Authorization: Bearer YOUR_USER_JWT` and JSON `{ "orderId": "YOUR_ORDER_ID" }`.
- Verify by MD5: `POST /api/payments/bakong/verify` with the same user JWT and JSON `{ "md5": "MD5_FROM_CREATE_RESPONSE" }`.
- Token status: `GET /api/payments/bakong/token` with `x-admin-api-key: YOUR_ADMIN_API_KEY`.
- Save token: `POST /api/payments/bakong/token` with `x-admin-api-key` and JSON `{ "token": "YOUR_SIT_TOKEN", "email": "YOUR_REGISTERED_EMAIL" }`.

This project archive is a code update; it cannot validate your private ABA credentials or perform a real money transfer. Confirm the account details and test with the official SIT environment before production use.

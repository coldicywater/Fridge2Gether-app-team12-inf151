# Fridge2Gether Privacy Policy

Last updated: November 22, 2026

Fridge2Gether is a student project (UC Irvine, INF 151, Team 12) that helps roommates track and share the food in their fridge.

## What we collect

- **Your name**, which you type in when you start. Roommates in your fridge can see it.
- **An anonymous account ID** created by Firebase Authentication. We do not ask for your email, phone number or password.
- **Food you add**: name, amount, expiry date, who it is shared with, and a small picture of the item.
- **Chat messages** you send in your fridge's group chat.

## How it is used

- Your fridge data and chat are stored in Google Firebase (Firestore) so roommates in the same fridge see the same items in real time. Only members of a fridge can read its food and chat.
- AI requests pass through our server on Cloudflare Workers, which only forwards them and does not store them.
- When you scan groceries, the photo is sent to the DeepSeek API to recognize the food. When you ask for recipes, the names, amounts and expiry dates of your food are sent to DeepSeek to write recipes. DeepSeek returns the result and we do not send it anything else about you.
- Expiry reminders are local notifications scheduled on your phone.

We do not sell your data, show ads, or track you across other apps or websites.

## Deleting your data

In the app, tap your avatar, then **Delete my account and data**. This removes your food from every fridge, takes you out of all your fridges, and deletes your profile and account. Messages you already sent in a group chat stay visible to the other members.

Deleting the app also removes the local data on your phone.

## Contact

Questions or deletion requests: liangbaikai2323@gmail.com

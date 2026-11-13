-- Takes the test data of vault_test_data.sql out of every account: the items and folders whose id starts with 5eed0000.
-- Their skills and folder links go with them. Folders the account had itself are not touched, and items of the account
-- that were in a test folder stay in the vault. Run it in the Supabase SQL editor.

begin;

delete from public.vault_items where id::text like '5eed0000-%';
delete from public.vault_folders where id::text like '5eed0000-%';

commit;

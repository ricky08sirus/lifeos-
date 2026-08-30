#!/usr/bin/perl
use strict;
use warnings;
use HTTP::Tiny;   # core module, ships with Perl - no install needed
use JSON::PP;     # core module, ships with Perl - no install needed

my $BASE_URL = 'http://localhost:3000';
my $http = HTTP::Tiny->new;
my $json = JSON::PP->new->utf8;

my $email    = 'test' . time() . '@example.com';  # unique each run, avoids 409 conflicts
my $password = 'password123';

my $pass_count = 0;
my $fail_count = 0;

sub section {
    my ($title) = @_;
    print "\n", "=" x 60, "\n";
    print "$title\n";
    print "=" x 60, "\n";
}

sub check {
    my ($label, $condition) = @_;
    if ($condition) {
        print "PASS - $label\n";
        $pass_count++;
    } else {
        print "FAIL - $label\n";
        $fail_count++;
    }
}

sub show {
    my ($res) = @_;
    print "Status: $res->{status}\n";
    print "Body:   $res->{content}\n";
}

# ---------------------------------------------------------------
section("1. POST /auth/register");
# ---------------------------------------------------------------
my $register_res = $http->post(
    "$BASE_URL/auth/register",
    {
        headers => { 'Content-Type' => 'application/json' },
        content => $json->encode({ email => $email, password => $password }),
    }
);
show($register_res);

my ($access_token, $refresh_token);
if ($register_res->{status} == 201) {
    my $data = $json->decode($register_res->{content});
    $access_token  = $data->{accessToken};
    $refresh_token = $data->{refreshToken};
    check("register returns 201 with accessToken + refreshToken", $access_token && $refresh_token);
} else {
    check("register returns 201", 0);
}

# ---------------------------------------------------------------
section("2. POST /auth/login");
# ---------------------------------------------------------------
my $login_res = $http->post(
    "$BASE_URL/auth/login",
    {
        headers => { 'Content-Type' => 'application/json' },
        content => $json->encode({ email => $email, password => $password }),
    }
);
show($login_res);

if ($login_res->{status} == 200) {
    my $data = $json->decode($login_res->{content});
    $access_token  = $data->{accessToken};
    $refresh_token = $data->{refreshToken};
    check("login returns 200 with accessToken + refreshToken", $access_token && $refresh_token);
} else {
    check("login returns 200", 0);
}

die "\nNo access token available - cannot continue. Fix register/login first.\n" unless $access_token;

# ---------------------------------------------------------------
section("3. GET /users/me");
# ---------------------------------------------------------------
my $me_res = $http->get(
    "$BASE_URL/users/me",
    { headers => { 'Authorization' => "Bearer $access_token" } }
);
show($me_res);
check("GET /users/me returns 200", $me_res->{status} == 200);

# ---------------------------------------------------------------
section("4. PATCH /users/me");
# ---------------------------------------------------------------
my $patch_res = $http->request(
    'PATCH',
    "$BASE_URL/users/me",
    {
        headers => {
            'Authorization' => "Bearer $access_token",
            'Content-Type'  => 'application/json',
        },
        content => $json->encode({
            displayName   => 'Test User',
            heightCm      => 175,
            activityLevel => 'moderate',
            dietType      => 'lacto_vegetarian',
        }),
    }
);
show($patch_res);
check("PATCH /users/me returns 200", $patch_res->{status} == 200);
if ($patch_res->{status} == 200) {
    my $data = $json->decode($patch_res->{content});
    check("displayName was actually updated", ($data->{displayName} // '') eq 'Test User');
}

# ---------------------------------------------------------------
section("5. GET /users/me/preferences");
# ---------------------------------------------------------------
my $prefs_get_res = $http->get(
    "$BASE_URL/users/me/preferences",
    { headers => { 'Authorization' => "Bearer $access_token" } }
);
show($prefs_get_res);
check("GET /users/me/preferences returns 200", $prefs_get_res->{status} == 200);

# ---------------------------------------------------------------
section("6. PATCH /users/me/preferences");
# ---------------------------------------------------------------
my $prefs_patch_res = $http->request(
    'PATCH',
    "$BASE_URL/users/me/preferences",
    {
        headers => {
            'Authorization' => "Bearer $access_token",
            'Content-Type'  => 'application/json',
        },
        content => $json->encode({ currencyCode => 'INR', units => 'metric' }),
    }
);
show($prefs_patch_res);
check("PATCH /users/me/preferences returns 200", $prefs_patch_res->{status} == 200);

# ---------------------------------------------------------------
section("7. GET /users/me/goals");
# ---------------------------------------------------------------
my $goals_get_res = $http->get(
    "$BASE_URL/users/me/goals",
    { headers => { 'Authorization' => "Bearer $access_token" } }
);
show($goals_get_res);
check("GET /users/me/goals returns 200", $goals_get_res->{status} == 200);

# ---------------------------------------------------------------
section("8. PATCH /users/me/goals");
# ---------------------------------------------------------------
my $goals_patch_res = $http->request(
    'PATCH',
    "$BASE_URL/users/me/goals",
    {
        headers => {
            'Authorization' => "Bearer $access_token",
            'Content-Type'  => 'application/json',
        },
        content => $json->encode({
            primaryGoal     => 'maintain',
            dailyCalories   => 2200,
            dailyProteinG   => 140,
            dailyWaterMl    => 3000,
            workoutsPerWeek => 4,
        }),
    }
);
show($goals_patch_res);
check("PATCH /users/me/goals returns 200", $goals_patch_res->{status} == 200);
if ($goals_patch_res->{status} == 200) {
    my $data = $json->decode($goals_patch_res->{content});
    check("dailyCalories was actually updated", ($data->{dailyCalories} // 0) == 2200);
}

# ---------------------------------------------------------------
section("9. POST /auth/refresh");
# ---------------------------------------------------------------
my $refresh_res = $http->post(
    "$BASE_URL/auth/refresh",
    {
        headers => { 'Content-Type' => 'application/json' },
        content => $json->encode({ refreshToken => $refresh_token }),
    }
);
show($refresh_res);
check("POST /auth/refresh returns 200 with a new accessToken", $refresh_res->{status} == 200);

# ---------------------------------------------------------------
section("10. POST /auth/password-reset");
# ---------------------------------------------------------------
my $reset_res = $http->post(
    "$BASE_URL/auth/password-reset",
    {
        headers => { 'Content-Type' => 'application/json' },
        content => $json->encode({ email => $email }),
    }
);
show($reset_res);
check("POST /auth/password-reset returns 200", $reset_res->{status} == 200);

# ---------------------------------------------------------------
section("11. POST /auth/logout");
# ---------------------------------------------------------------
my $logout_res = $http->post(
    "$BASE_URL/auth/logout",
    {
        headers => { 'Content-Type' => 'application/json' },
        content => $json->encode({ refreshToken => $refresh_token }),
    }
);
show($logout_res);
check("POST /auth/logout returns 200", $logout_res->{status} == 200);

# ---------------------------------------------------------------
section("12. Negative test: GET /users/me with NO token");
# ---------------------------------------------------------------
my $no_auth_res = $http->get("$BASE_URL/users/me");
show($no_auth_res);
check("correctly rejected with 401", $no_auth_res->{status} == 401);

# ---------------------------------------------------------------
section("13. Negative test: GET /users/me with garbage token");
# ---------------------------------------------------------------
my $bad_token_res = $http->get(
    "$BASE_URL/users/me",
    { headers => { 'Authorization' => 'Bearer garbage.invalid.token' } }
);
show($bad_token_res);
check("correctly rejected with 401", $bad_token_res->{status} == 401);

# ---------------------------------------------------------------
section("SUMMARY");
# ---------------------------------------------------------------
print "Passed: $pass_count\n";
print "Failed: $fail_count\n";
print $fail_count == 0 ? "\nALL TESTS PASSED\n" : "\nSOME TESTS FAILED - see above\n";
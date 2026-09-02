# #!/usr/bin/perl
# use strict;
# use warnings;
# use HTTP::Tiny;   # core module, ships with Perl - no install needed
# use JSON::PP;     # core module, ships with Perl - no install needed

# my $BASE_URL = 'http://localhost:3000';
# my $http = HTTP::Tiny->new;
# my $json = JSON::PP->new->utf8;

# my $email    = 'test' . time() . '@example.com';  # unique each run, avoids 409 conflicts
# my $password = 'password123';

# my $pass_count = 0;
# my $fail_count = 0;

# sub section {
#     my ($title) = @_;
#     print "\n", "=" x 60, "\n";
#     print "$title\n";
#     print "=" x 60, "\n";
# }

# sub check {
#     my ($label, $condition) = @_;
#     if ($condition) {
#         print "PASS - $label\n";
#         $pass_count++;
#     } else {
#         print "FAIL - $label\n";
#         $fail_count++;
#     }
# }

# sub show {
#     my ($res) = @_;
#     print "Status: $res->{status}\n";
#     print "Body:   $res->{content}\n";
# }

# # ---------------------------------------------------------------
# section("1. POST /auth/register");
# # ---------------------------------------------------------------
# my $register_res = $http->post(
#     "$BASE_URL/auth/register",
#     {
#         headers => { 'Content-Type' => 'application/json' },
#         content => $json->encode({ email => $email, password => $password }),
#     }
# );
# show($register_res);

# my ($access_token, $refresh_token);
# if ($register_res->{status} == 201) {
#     my $data = $json->decode($register_res->{content});
#     $access_token  = $data->{accessToken};
#     $refresh_token = $data->{refreshToken};
#     check("register returns 201 with accessToken + refreshToken", $access_token && $refresh_token);
# } else {
#     check("register returns 201", 0);
# }

# # ---------------------------------------------------------------
# section("2. POST /auth/login");
# # ---------------------------------------------------------------
# my $login_res = $http->post(
#     "$BASE_URL/auth/login",
#     {
#         headers => { 'Content-Type' => 'application/json' },
#         content => $json->encode({ email => $email, password => $password }),
#     }
# );
# show($login_res);

# if ($login_res->{status} == 200) {
#     my $data = $json->decode($login_res->{content});
#     $access_token  = $data->{accessToken};
#     $refresh_token = $data->{refreshToken};
#     check("login returns 200 with accessToken + refreshToken", $access_token && $refresh_token);
# } else {
#     check("login returns 200", 0);
# }

# die "\nNo access token available - cannot continue. Fix register/login first.\n" unless $access_token;

# # ---------------------------------------------------------------
# section("3. GET /users/me");
# # ---------------------------------------------------------------
# my $me_res = $http->get(
#     "$BASE_URL/users/me",
#     { headers => { 'Authorization' => "Bearer $access_token" } }
# );
# show($me_res);
# check("GET /users/me returns 200", $me_res->{status} == 200);

# # ---------------------------------------------------------------
# section("4. PATCH /users/me");
# # ---------------------------------------------------------------
# my $patch_res = $http->request(
#     'PATCH',
#     "$BASE_URL/users/me",
#     {
#         headers => {
#             'Authorization' => "Bearer $access_token",
#             'Content-Type'  => 'application/json',
#         },
#         content => $json->encode({
#             displayName   => 'Test User',
#             heightCm      => 175,
#             activityLevel => 'moderate',
#             dietType      => 'lacto_vegetarian',
#         }),
#     }
# );
# show($patch_res);
# check("PATCH /users/me returns 200", $patch_res->{status} == 200);
# if ($patch_res->{status} == 200) {
#     my $data = $json->decode($patch_res->{content});
#     check("displayName was actually updated", ($data->{displayName} // '') eq 'Test User');
# }

# # ---------------------------------------------------------------
# section("5. GET /users/me/preferences");
# # ---------------------------------------------------------------
# my $prefs_get_res = $http->get(
#     "$BASE_URL/users/me/preferences",
#     { headers => { 'Authorization' => "Bearer $access_token" } }
# );
# show($prefs_get_res);
# check("GET /users/me/preferences returns 200", $prefs_get_res->{status} == 200);

# # ---------------------------------------------------------------
# section("6. PATCH /users/me/preferences");
# # ---------------------------------------------------------------
# my $prefs_patch_res = $http->request(
#     'PATCH',
#     "$BASE_URL/users/me/preferences",
#     {
#         headers => {
#             'Authorization' => "Bearer $access_token",
#             'Content-Type'  => 'application/json',
#         },
#         content => $json->encode({ currencyCode => 'INR', units => 'metric' }),
#     }
# );
# show($prefs_patch_res);
# check("PATCH /users/me/preferences returns 200", $prefs_patch_res->{status} == 200);

# # ---------------------------------------------------------------
# section("7. GET /users/me/goals");
# # ---------------------------------------------------------------
# my $goals_get_res = $http->get(
#     "$BASE_URL/users/me/goals",
#     { headers => { 'Authorization' => "Bearer $access_token" } }
# );
# show($goals_get_res);
# check("GET /users/me/goals returns 200", $goals_get_res->{status} == 200);

# # ---------------------------------------------------------------
# section("8. PATCH /users/me/goals");
# # ---------------------------------------------------------------
# my $goals_patch_res = $http->request(
#     'PATCH',
#     "$BASE_URL/users/me/goals",
#     {
#         headers => {
#             'Authorization' => "Bearer $access_token",
#             'Content-Type'  => 'application/json',
#         },
#         content => $json->encode({
#             primaryGoal     => 'maintain',
#             dailyCalories   => 2200,
#             dailyProteinG   => 140,
#             dailyWaterMl    => 3000,
#             workoutsPerWeek => 4,
#         }),
#     }
# );
# show($goals_patch_res);
# check("PATCH /users/me/goals returns 200", $goals_patch_res->{status} == 200);
# if ($goals_patch_res->{status} == 200) {
#     my $data = $json->decode($goals_patch_res->{content});
#     check("dailyCalories was actually updated", ($data->{dailyCalories} // 0) == 2200);
# }

# # ---------------------------------------------------------------
# section("9. POST /auth/refresh");
# # ---------------------------------------------------------------
# my $refresh_res = $http->post(
#     "$BASE_URL/auth/refresh",
#     {
#         headers => { 'Content-Type' => 'application/json' },
#         content => $json->encode({ refreshToken => $refresh_token }),
#     }
# );
# show($refresh_res);
# check("POST /auth/refresh returns 200 with a new accessToken", $refresh_res->{status} == 200);

# # ---------------------------------------------------------------
# section("10. POST /auth/password-reset");
# # ---------------------------------------------------------------
# my $reset_res = $http->post(
#     "$BASE_URL/auth/password-reset",
#     {
#         headers => { 'Content-Type' => 'application/json' },
#         content => $json->encode({ email => $email }),
#     }
# );
# show($reset_res);
# check("POST /auth/password-reset returns 200", $reset_res->{status} == 200);

# # ---------------------------------------------------------------
# section("11. POST /auth/logout");
# # ---------------------------------------------------------------
# my $logout_res = $http->post(
#     "$BASE_URL/auth/logout",
#     {
#         headers => { 'Content-Type' => 'application/json' },
#         content => $json->encode({ refreshToken => $refresh_token }),
#     }
# );
# show($logout_res);
# check("POST /auth/logout returns 200", $logout_res->{status} == 200);

# # ---------------------------------------------------------------
# section("12. Negative test: GET /users/me with NO token");
# # ---------------------------------------------------------------
# my $no_auth_res = $http->get("$BASE_URL/users/me");
# show($no_auth_res);
# check("correctly rejected with 401", $no_auth_res->{status} == 401);

# # ---------------------------------------------------------------
# section("13. Negative test: GET /users/me with garbage token");
# # ---------------------------------------------------------------
# my $bad_token_res = $http->get(
#     "$BASE_URL/users/me",
#     { headers => { 'Authorization' => 'Bearer garbage.invalid.token' } }
# );
# show($bad_token_res);
# check("correctly rejected with 401", $bad_token_res->{status} == 401);

# # ---------------------------------------------------------------
# section("SUMMARY");
# # ---------------------------------------------------------------
# print "Passed: $pass_count\n";
# print "Failed: $fail_count\n";
# print $fail_count == 0 ? "\nALL TESTS PASSED\n" : "\nSOME TESTS FAILED - see above\n";









#!/usr/bin/perl
use strict;
use warnings;
use HTTP::Tiny;   # core module, ships with Perl - no install needed
use JSON::PP;     # core module, ships with Perl - no install needed

my $BASE_URL = 'http://localhost:3000';
my $http = HTTP::Tiny->new;
my $json = JSON::PP->new->utf8;

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

sub auth_headers {
    my ($token, $with_json) = @_;
    my %h = ( 'Authorization' => "Bearer $token" );
    $h{'Content-Type'} = 'application/json' if $with_json;
    return \%h;
}

sub register_and_login {
    my $email    = 'test' . time() . '_' . int(rand(100000)) . '@example.com';
    my $password = 'password123';
    my $res = $http->post(
        "$BASE_URL/auth/register",
        {
            headers => { 'Content-Type' => 'application/json' },
            content => $json->encode({ email => $email, password => $password }),
        }
    );
    return undef unless $res->{status} == 201;
    my $data = eval { $json->decode($res->{content}) };
    return $data ? $data->{accessToken} : undef;
}

# ---------------------------------------------------------------
section("0. Register two users (user A = primary, user B = for isolation checks)");
# ---------------------------------------------------------------
my $token_a = register_and_login();
check("user A registered and got accessToken", $token_a ? 1 : 0);
die "\nCannot continue without user A token.\n" unless $token_a;

my $token_b = register_and_login();
check("user B registered and got accessToken", $token_b ? 1 : 0);

# ---------------------------------------------------------------
# Generic CRUD tester for a resource mounted at /health/<path>
#
# name            - human readable label, e.g. "Weights"
# path            - url path under /health, e.g. "weights"
# create_payload  - hashref sent on POST (valid)
# invalid_payload - hashref sent on POST that should trigger a 400
# patch_payload   - hashref sent on PATCH
# patch_field     - field name to verify after PATCH
# patch_value     - expected value of patch_field after PATCH
# list_query      - optional query string to smoke-test filtering, e.g. "site=waist"
# ---------------------------------------------------------------
sub test_resource {
    my (%args) = @_;
    my $name            = $args{name};
    my $path             = "health/$args{path}";
    my $create_payload   = $args{create_payload};
    my $invalid_payload  = $args{invalid_payload};
    my $patch_payload    = $args{patch_payload};
    my $patch_field      = $args{patch_field};
    my $patch_value      = $args{patch_value};
    my $list_query       = $args{list_query};

    section("$name: POST /$path with invalid body (expect 400)");
    if ($invalid_payload) {
        my $bad_res = $http->post(
            "$BASE_URL/$path",
            {
                headers => auth_headers($token_a, 1),
                content => $json->encode($invalid_payload),
            }
        );
        show($bad_res);
        check("$name POST with missing required field returns 400", $bad_res->{status} == 400);
    } else {
        print "(skipped - no invalid payload defined)\n";
    }

    section("$name: POST /$path (create, valid)");
    my $create_res = $http->post(
        "$BASE_URL/$path",
        {
            headers => auth_headers($token_a, 1),
            content => $json->encode($create_payload),
        }
    );
    show($create_res);
    check("$name create returns 201", $create_res->{status} == 201);

    my $id;
    if ($create_res->{status} == 201) {
        my $data = eval { $json->decode($create_res->{content}) };
        $id = $data->{id} if $data;
        check("$name create response includes id", $id ? 1 : 0);
    }
    return unless $id;

    section("$name: GET /$path (list, bare array)");
    my $list_res = $http->get(
        "$BASE_URL/$path",
        { headers => auth_headers($token_a, 0) }
    );
    show($list_res);
    check("$name list returns 200", $list_res->{status} == 200);
    if ($list_res->{status} == 200) {
        my $data = eval { $json->decode($list_res->{content}) };
        check("$name list response is a bare JSON array", ref($data) eq 'ARRAY');
        my $found = ref($data) eq 'ARRAY' && grep { ($_->{id} // '') eq $id } @$data;
        check("$name list contains newly created entry", $found ? 1 : 0);
    }

    if ($list_query) {
        section("$name: GET /$path?$list_query (filter smoke test)");
        my $filtered_res = $http->get(
            "$BASE_URL/$path?$list_query",
            { headers => auth_headers($token_a, 0) }
        );
        show($filtered_res);
        check("$name filtered list returns 200", $filtered_res->{status} == 200);
    }

    section("$name: PATCH /$path/$id (update)");
    my $patch_res = $http->request(
        'PATCH',
        "$BASE_URL/$path/$id",
        {
            headers => auth_headers($token_a, 1),
            content => $json->encode($patch_payload),
        }
    );
    show($patch_res);
    check("$name PATCH returns 200", $patch_res->{status} == 200);
    if ($patch_res->{status} == 200 && defined $patch_field) {
        my $data = eval { $json->decode($patch_res->{content}) };
        check("$name PATCH actually updated $patch_field",
            $data && (($data->{$patch_field} // '') eq $patch_value));
    }

    section("$name: Negative - no auth token at all");
    my $no_auth_res = $http->get("$BASE_URL/$path");
    show($no_auth_res);
    check("$name GET list with no auth returns 401", $no_auth_res->{status} == 401);

    if ($token_b) {
        section("$name: Isolation - user B cannot see/edit/delete user A's entry");
        my $b_get_res = $http->get(
            "$BASE_URL/$path",
            { headers => auth_headers($token_b, 0) }
        );
        show($b_get_res);
        if ($b_get_res->{status} == 200) {
            my $data = eval { $json->decode($b_get_res->{content}) };
            my $leaked = ref($data) eq 'ARRAY' && grep { ($_->{id} // '') eq $id } @$data;
            check("$name user B's list does not contain user A's entry", !$leaked);
        }

        my $b_patch_res = $http->request(
            'PATCH',
            "$BASE_URL/$path/$id",
            {
                headers => auth_headers($token_b, 1),
                content => $json->encode($patch_payload),
            }
        );
        show($b_patch_res);
        check("$name user B PATCH on user A's entry returns 404", $b_patch_res->{status} == 404);

        my $b_delete_res = $http->request(
            'DELETE',
            "$BASE_URL/$path/$id",
            { headers => auth_headers($token_b, 0) }
        );
        show($b_delete_res);
        check("$name user B DELETE on user A's entry returns 404", $b_delete_res->{status} == 404);
    }

    section("$name: DELETE /$path/$id (as owner, user A)");
    my $delete_res = $http->request(
        'DELETE',
        "$BASE_URL/$path/$id",
        { headers => auth_headers($token_a, 0) }
    );
    show($delete_res);
    check("$name DELETE returns 204", $delete_res->{status} == 204);

    section("$name: PATCH /$path/$id after delete (should 404)");
    my $after_delete_res = $http->request(
        'PATCH',
        "$BASE_URL/$path/$id",
        {
            headers => auth_headers($token_a, 1),
            content => $json->encode($patch_payload),
        }
    );
    show($after_delete_res);
    check("$name PATCH after delete returns 404", $after_delete_res->{status} == 404);
}

# ---------------------------------------------------------------
# 1. Weights
# ---------------------------------------------------------------
test_resource(
    name            => 'Weights',
    path            => 'weights',
    create_payload  => { date => '2026-09-01T00:00:00.000Z', kg => 72.5 },
    invalid_payload => { date => '2026-09-01T00:00:00.000Z' },  # missing kg
    patch_payload   => { kg => 71.8 },
    patch_field     => 'kg',
    patch_value     => 71.8,
    list_query      => 'from=2026-01-01&to=2026-12-31',
);

# ---------------------------------------------------------------
# 2. Measurements
# ---------------------------------------------------------------
test_resource(
    name            => 'Measurements',
    path            => 'measurements',
    create_payload  => { date => '2026-09-01T00:00:00.000Z', site => 'waist', valueCm => 85.0 },
    invalid_payload => { date => '2026-09-01T00:00:00.000Z', valueCm => 85.0 },  # missing site
    patch_payload   => { valueCm => 84.2 },
    patch_field     => 'valueCm',
    patch_value     => 84.2,
    list_query      => 'site=waist',
);

# ---------------------------------------------------------------
# 3. Sleep
# ---------------------------------------------------------------
test_resource(
    name            => 'Sleep',
    path            => 'sleep',
    create_payload  => {
        date            => '2026-09-01T00:00:00.000Z',
        durationMinutes => 420,
        quality         => 4,
        interruptions   => 1,
    },
    invalid_payload => { date => '2026-09-01T00:00:00.000Z' },  # missing durationMinutes
    patch_payload   => { quality => 5 },
    patch_field     => 'quality',
    patch_value     => 5,
    list_query      => 'from=2026-01-01&to=2026-12-31',
);

# ---------------------------------------------------------------
# 4. Wellbeing
# ---------------------------------------------------------------
test_resource(
    name            => 'Wellbeing',
    path            => 'wellbeing',
    create_payload  => {
        date     => '2026-09-01T00:00:00.000Z',
        mood     => 4,
        stress   => 2,
        energy   => 3,
        soreness => 1,
        fatigue  => 2,
    },
    invalid_payload => { mood => 4 },  # missing date
    patch_payload   => { mood => 5 },
    patch_field     => 'mood',
    patch_value     => 5,
    list_query      => 'from=2026-01-01&to=2026-12-31',
);

# ---------------------------------------------------------------
# 5. Vitals (resting_heart_rate)
# ---------------------------------------------------------------
test_resource(
    name            => 'Vitals (heart rate)',
    path            => 'vitals',
    create_payload  => { kind => 'resting_heart_rate', value => 58 },
    invalid_payload => { kind => 'resting_heart_rate' },  # missing value
    patch_payload   => { value => 60 },
    patch_field     => 'value',
    patch_value     => 60,
    list_query      => 'kind=resting_heart_rate',
);

# ---------------------------------------------------------------
# 6. Vitals (blood_pressure) - separate kind-specific validation
# ---------------------------------------------------------------
section("Vitals (blood pressure): POST /health/vitals missing systolic/diastolic (expect 400)");
my $bp_bad_res = $http->post(
    "$BASE_URL/health/vitals",
    {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ kind => 'blood_pressure' }),
    }
);
show($bp_bad_res);
check("blood_pressure POST missing systolic/diastolic returns 400", $bp_bad_res->{status} == 400);

section("Vitals (blood pressure): POST /health/vitals (valid)");
my $bp_res = $http->post(
    "$BASE_URL/health/vitals",
    {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ kind => 'blood_pressure', systolic => 120, diastolic => 80 }),
    }
);
show($bp_res);
check("blood_pressure POST with systolic/diastolic returns 201", $bp_res->{status} == 201);
if ($bp_res->{status} == 201) {
    my $data = eval { $json->decode($bp_res->{content}) };
    check("blood_pressure entry stored correct systolic/diastolic",
        $data && $data->{systolic} == 120 && $data->{diastolic} == 80);
}

# ---------------------------------------------------------------
section("SUMMARY");
# ---------------------------------------------------------------
print "Passed: $pass_count\n";
print "Failed: $fail_count\n";
print $fail_count == 0 ? "\nALL TESTS PASSED\n" : "\nSOME TESTS FAILED - see above\n";


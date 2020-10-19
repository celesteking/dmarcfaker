
require 'securerandom'

time_now_float = -> { "%10.6f" % Time.now.to_f }

SPF_RESTYPE_GOOD = %w[ pass none neutral temperror ]
SPF_RESTYPE_BAD = %w[ fail softfail permerror ]
DKIM_RESTYPE_GOOD = %w[ pass policy ]
DKIM_RESTYPE_BAD = %w[ fail neutral temperror permerror ]

FactoryBot.define do
  sequence :policy_domain do |idx|
    DATA.domains[(idx - 1) % DATA.domains.size]
  end

  sequence :policy_alignment_dkim, aliases: [:policy_alignment_spf] do |idx|
    idx.even?? 's' : 'r'
  end

  factory :feedback do
    transient do
      random_domain { }
      domain { random_domain ? Faker::Internet.domain_name : generate(:policy_domain) }
      record_count { 3 }
      time {{ backward: 7 }}
    end

    version { 1.0 }
    report_metadata { association :report_metadata, time: time }

    policy_published { association :policy_published, domain: domain }

    record { record_count.times.map { build(:record, domain: domain) } }
  end

  factory :report_metadata do
    transient do
      time {}
      org_info { DATA.orgs.sample }
    end

    org_name { org_info.org_name }
    email { org_info.email }
    extra_contact_info { org_info.extra_contact_info }

    report_id {
      [
        -> { SecureRandom.uuid },
        time_now_float
      ].sample.()
    }
    date_range {
      if (days = time[:backward])
        start = Time.now.to_date - days
        finish = Time.now.to_date
      else
        start = time[:start]
        finish = time[:end]
      end
      H[{
        begin: start.strftime('%s'),
        end: finish.strftime('%s'),
      }]
    }
  end

  factory :policy_published do
    domain { }
    adkim { generate(:policy_alignment_dkim) }
    aspf { adkim }
    p { 'none' }
    sp { 'none' }
    pct { '100' }
    fo { '' }
  end

  factory :record do
    transient do
      domain {}
      subdomain_or_domain {
        rand < 0.5 ? Faker::Creature::Dog.name.downcase + ".#{domain}" : domain
      }
      hdrfrom_or_ran_dom {
        if (dice = rand) < 0.1
          Faker::Internet.domain_name
        elsif dice > 0.1 and dice < 0.3
          subdomain_or_domain
        else
          nil
        end
      }
      unlikely_ran_dom {
        if (dice = rand) < 0.1
          Faker::Internet.domain_name
        else
          nil
        end
      }
      spf_eval_result { rand > 0.2 }
      dkim_eval_result {
        if (dice = rand) < 0.2
          :missing
        elsif dice > 0.1 and dice < 0.3
          :fail
        else
          :pass
        end
      }
    end

    row { association :row,
        source_ip: Faker::Internet.public_ip_v4_address, count: rand(100).to_i,
        policy_eval_result_spf: spf_eval_result, policy_eval_result_dkim: dkim_eval_result
    }

    identifiers {H[{
        header_from: subdomain_or_domain,
        envelope_to: unlikely_ran_dom,
        envelope_from: hdrfrom_or_ran_dom,
    }]}

    auth_results { association :auth_results, header_from: subdomain_or_domain, envelope_from: hdrfrom_or_ran_dom,
        policy_eval_result_spf: spf_eval_result, policy_eval_result_dkim: dkim_eval_result }
  end

  factory :row do
    transient do
      policy_eval_result_spf { false }
      policy_eval_result_dkim { :missing }
      policy_eval_result {
        policy_eval_result_spf or policy_eval_result_dkim == :pass # note: dkim might be missing
      }
    end

    source_ip {}
    count {}
    policy_evaluated {
      base = {
        disposition: 'none',
        dkim: policy_eval_result_dkim == :pass ? 'pass' : 'fail',
        spf: policy_eval_result_spf ? 'pass' : 'fail',
      }
      if !policy_eval_result and rand < 0.1
        base[:reason] = [{
            type: 'local_policy',
            comment: 'arc=pass',
        }]
      end
      H.new(base)
    }
  end

  factory :auth_results do
    transient do
      header_from {}
      envelope_from {}
      policy_eval_result_spf {}
      policy_eval_result_dkim {}
      spf_auth_results_count { 1 + (rand < 0.2 ? 1 : 0) }
      dkim_auth_results_count { (policy_eval_result_dkim == :missing) ? 0 : (rand > 0.2 ? 1 : 2) } # 0..2
    end

    dkim  {
      if dkim_auth_results_count == 2 && policy_eval_result_dkim == :pass
        outcome = rand > 0.5 ? [:pass, :pass] : [:pass, :fail].shuffle
      else
        outcome = dkim_auth_results_count.times.map { policy_eval_result_dkim }
      end

      dkim_auth_results_count.times.map {|idx| build(:dkim_auth_results, header_from: header_from, outcome: outcome[idx])  }
    } # size >=0

    spf   { spf_auth_results_count.times.map {|idx| build(:spf_auth_results, header_from: header_from,
                envelope_from: envelope_from, outcome: policy_eval_result_spf, first: idx == 0) }
    } # size >=1
  end

  factory :spf_auth_results do
    transient do
      header_from {}
      envelope_from {}
      outcome {}
      first {} # first spf entry?
    end
    domain { (rand < 0.2 or not first) ? Faker::Internet.domain_name : (envelope_from or header_from) }
    scope { first ? 'mfrom' : 'helo' }
    result {
      if (first and outcome) or (not first and rand > 0.5)
        SPF_RESTYPE_GOOD[(rand < 0.5) ? 0 : 1 + rand(3).to_i]
      else
        SPF_RESTYPE_BAD[(rand < 0.5) ? 0 : 1 + rand(2).to_i]
      end
    }
  end

  factory :dkim_auth_results do
    transient do
      header_from {}
      outcome {}
    end

    domain { # req
      if outcome == :fail
        rand < 0.3 ? header_from : Faker::Internet.domain_name
      else
        header_from
      end
    }
    result { # req
      if outcome == :pass
        DKIM_RESTYPE_GOOD[rand < 0.9 ? 0 : 1]
      else
        DKIM_RESTYPE_BAD[ case rand when 0...0.5; 0 when 0.5...0.7; 1 else [2,3].sample; end ]
      end
    }
    selector { #  opt
      rand < 0.7 ? 'default' : Faker::Creature::Cat.name.downcase
    }
    # human_result {} # opt # always missing in reports
  end
end

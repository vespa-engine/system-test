# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class TensorUnstableCellTypesTest < IndexedSearchTest

  def setup
    set_owner('arnej')
  end

  def test_tensor_unstable_cell_types
    set_description('Test tensor evaluation with unstable cell types')
    deploy_app(SearchApp.new.sd(selfdir + 'unstable.sd').search_dir(selfdir + 'unstable_search'))
    start
    feed_and_wait_for_docs('unstable', 3, :file => selfdir + 'unstable-docs.json')
    expect_scores = [ 525, 580, 330, 412.5, 475, 460, 270, 337.5, 350, 360, 220, 275, 200, 240, 160, 200 ]
    idx = 0
    [ 'default', 'w32bits', 'w16bits', 'w8bits' ].each do |rprofile|
      [ 'kid', 'adult' ].each do |qa|
        [ 'f', 'm' ].each do |qs|
            q = '?query=sddocname:unstable'
            q += '&ranking.profile=' + rprofile
            q += '&ranking.features.query(age)={{age:' + qa + '}:1.5}'
            q += '&ranking.features.query(sex)={{sex:' + qs + '}:2}'
            q += '&format=json'
            q += '&format.tensors=long'
            result = search(q)
            #puts result.xmldata
            assert_equal(result.hit.size, 1)
            firsthit = result.hit[0]
            puts ("q(age=#{qa}, sex=#{qs}, #{rprofile}) : #{result.hit.size} hit, " +
                  "score: #{firsthit.field['relevancy']} / title: #{firsthit.field['title']}")
            assert_equal(firsthit.field['relevancy'].to_f, 3.0 * expect_scores[idx])
            sfs = firsthit.field['summaryfeatures']
            if sfs
              out = sfs['output_tensor']
              cell = out['cells'].first
              puts "tensor type: #{out['type']} cell tag #{cell['address']['tag']} value #{cell['value']}"
            end
            idx += 1
        end
      end
    end
  end

  def teardown
    stop
  end

end

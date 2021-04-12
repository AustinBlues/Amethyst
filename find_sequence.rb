# depth first tree traversal to find a sequence of states that covers all 16
# (4x4) Post state transitions for change_to() testing

$transitions = [Array.new(4), Array.new(4), Array.new(4), Array.new(4)]

def find(state, depth)
  for i in 0..3 do
    if $transitions[state][i].nil?
      $transitions[state][i] = depth
      if depth >= 15
        puts "(#{depth}) #{state} => #{i}"
        return true
      elsif !find(i, depth+1)
        $transitions[state][i] = nil
      else
        puts "(#{depth}) #{state} => #{i}"
        return true
      end
    end
  end
  false
end

for i in 0..3 do
  find(i, 0)
end
puts "TRANS: #{$transitions.inspect}."
